from __future__ import annotations

import logging
import os
import subprocess
import tarfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

from ops.s3_utils import build_s3_client, get_backup_bucket_name, get_backup_prefix

BASE_DIR = Path(__file__).resolve().parent.parent
BACKUPS_DIR = BASE_DIR / "backups"
DB_BACKUPS_DIR = BACKUPS_DIR / "db"
LOG_BACKUPS_DIR = BACKUPS_DIR / "logs"
RUNTIME_LOGS_DIR = BASE_DIR / "runtime_logs"
TRUNCATE_AFTER_ARCHIVE = {
    "gunicorn_access.log",
    "gunicorn_error.log",
    "django.log",
    "django.error.log",
}


def build_logger() -> logging.Logger:
    logger = logging.getLogger("ops.backup")
    if logger.handlers:
        return logger

    RUNTIME_LOGS_DIR.mkdir(parents=True, exist_ok=True)
    logger.setLevel(os.getenv("APP_LOG_LEVEL", "INFO").upper())
    formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s")

    stream_handler = logging.StreamHandler()
    stream_handler.setFormatter(formatter)
    logger.addHandler(stream_handler)

    file_handler = logging.FileHandler(RUNTIME_LOGS_DIR / "backup.log", encoding="utf-8")
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    logger.propagate = False
    return logger


logger = build_logger()


def env_str(name: str, default: str = "") -> str:
    return os.getenv(name, default).strip()


def env_int(name: str, default: int) -> int:
    raw_value = env_str(name, str(default))
    try:
        return int(raw_value)
    except ValueError:
        return default


def run_command(command: list[str]) -> None:
    command_env = os.environ.copy()
    command_env["PGPASSWORD"] = env_str("POSTGRES_PASSWORD")
    subprocess.run(command, check=True, env=command_env)


def ensure_directories() -> None:
    DB_BACKUPS_DIR.mkdir(parents=True, exist_ok=True)
    LOG_BACKUPS_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_LOGS_DIR.mkdir(parents=True, exist_ok=True)


def create_db_backup(timestamp: str) -> Path:
    backup_path = DB_BACKUPS_DIR / f"{env_str('POSTGRES_DB', 'econizhny')}-{timestamp}.dump"
    command = [
        "pg_dump",
        "-Fc",
        "-h",
        env_str("POSTGRES_HOST", "db"),
        "-p",
        env_str("POSTGRES_PORT", "5432"),
        "-U",
        env_str("POSTGRES_USER", "econizhny"),
        "-d",
        env_str("POSTGRES_DB", "econizhny"),
        "-f",
        str(backup_path),
    ]
    run_command(command)
    logger.info("Database backup created: %s", backup_path)
    return backup_path


def create_logs_archive(timestamp: str) -> Path | None:
    log_files = [path for path in sorted(RUNTIME_LOGS_DIR.glob("*.log")) if path.is_file()]
    if not log_files:
        logger.info("No runtime log files found, skipping log archive")
        return None

    archive_path = LOG_BACKUPS_DIR / f"runtime-logs-{timestamp}.tar.gz"
    with tarfile.open(archive_path, "w:gz") as archive:
        for log_file in log_files:
            archive.add(log_file, arcname=log_file.name)
    logger.info("Log archive created: %s", archive_path)
    return archive_path


def truncate_runtime_logs() -> None:
    for log_name in TRUNCATE_AFTER_ARCHIVE:
        log_path = RUNTIME_LOGS_DIR / log_name
        if log_path.exists():
            log_path.write_text("", encoding="utf-8")


def upload_to_s3(file_path: Path, object_key: str) -> None:
    client = build_s3_client()
    bucket_name = get_backup_bucket_name()
    if client is None or not bucket_name:
        logger.info("S3 backup upload skipped for %s: storage is not configured", file_path)
        return

    client.upload_file(str(file_path), bucket_name, object_key)
    logger.info("Uploaded to S3: s3://%s/%s", bucket_name, object_key)


def prune_local_backups(retention_days: int) -> None:
    cutoff = datetime.now(timezone.utc) - timedelta(days=retention_days)
    for directory in (DB_BACKUPS_DIR, LOG_BACKUPS_DIR):
        for path in directory.iterdir():
            if not path.is_file() or path.name == ".gitkeep":
                continue
            modified_at = datetime.fromtimestamp(path.stat().st_mtime, tz=timezone.utc)
            if modified_at < cutoff:
                path.unlink(missing_ok=True)
                logger.info("Deleted old local backup: %s", path)


def prune_remote_backups(retention_days: int) -> None:
    client = build_s3_client()
    bucket_name = get_backup_bucket_name()
    if client is None or not bucket_name:
        return

    cutoff = datetime.now(timezone.utc) - timedelta(days=retention_days)
    prefix = get_backup_prefix()
    paginator = client.get_paginator("list_objects_v2")

    for page in paginator.paginate(Bucket=bucket_name, Prefix=f"{prefix}/"):
        objects_to_delete = []
        for item in page.get("Contents", []):
            if item["LastModified"] < cutoff:
                objects_to_delete.append({"Key": item["Key"]})
        if objects_to_delete:
            client.delete_objects(Bucket=bucket_name, Delete={"Objects": objects_to_delete})
            for item in objects_to_delete:
                logger.info("Deleted old remote backup: s3://%s/%s", bucket_name, item["Key"])


def execute_backup() -> None:
    ensure_directories()

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    retention_days = max(env_int("BACKUP_RETENTION_DAYS", 7), 1)
    prefix = get_backup_prefix()

    db_backup_path = create_db_backup(timestamp)
    log_archive_path = create_logs_archive(timestamp)

    upload_to_s3(db_backup_path, f"{prefix}/db/{db_backup_path.name}")
    if log_archive_path is not None:
        upload_to_s3(log_archive_path, f"{prefix}/logs/{log_archive_path.name}")
        truncate_runtime_logs()

    prune_local_backups(retention_days)
    prune_remote_backups(retention_days)
    logger.info("Backup cycle completed")


if __name__ == "__main__":
    execute_backup()
