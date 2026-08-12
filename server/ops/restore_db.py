from __future__ import annotations

import argparse
import os
import tempfile
from pathlib import Path

from ops.run_backup import logger, run_command
from ops.s3_utils import build_s3_client, get_backup_bucket_name, get_backup_prefix

BASE_DIR = Path(__file__).resolve().parent.parent


def env_str(name: str, default: str = "") -> str:
    return os.getenv(name, default).strip()


def resolve_source(source: str) -> Path:
    local_path = Path(source)
    if local_path.is_file():
        return local_path

    candidate_path = BASE_DIR / source
    if candidate_path.is_file():
        return candidate_path

    client = build_s3_client()
    bucket_name = get_backup_bucket_name()
    if client is None or not bucket_name:
        raise FileNotFoundError(f"Backup file was not found locally: {source}")

    normalized_key = source.removeprefix("s3://")
    if normalized_key.startswith(f"{bucket_name}/"):
        normalized_key = normalized_key[len(bucket_name) + 1 :]
    elif "/" not in normalized_key:
        normalized_key = f"{get_backup_prefix()}/db/{normalized_key}"

    temp_dir = Path(tempfile.mkdtemp(prefix="econizhny-restore-"))
    download_path = temp_dir / Path(normalized_key).name
    client.download_file(bucket_name, normalized_key, str(download_path))
    logger.info("Downloaded backup from S3: s3://%s/%s", bucket_name, normalized_key)
    return download_path


def restore_database(backup_path: Path) -> None:
    postgres_host = env_str("POSTGRES_HOST", "db")
    postgres_port = env_str("POSTGRES_PORT", "5432")
    postgres_user = env_str("POSTGRES_USER", "econizhny")
    database_name = env_str("POSTGRES_DB", "econizhny")

    run_command(
        [
            "psql",
            "-h",
            postgres_host,
            "-p",
            postgres_port,
            "-U",
            postgres_user,
            "-d",
            "postgres",
            "-c",
            (
                "SELECT pg_terminate_backend(pid) "
                f"FROM pg_stat_activity WHERE datname = '{database_name}' "
                "AND pid <> pg_backend_pid();"
            ),
        ]
    )
    run_command(
        [
            "dropdb",
            "--if-exists",
            "-h",
            postgres_host,
            "-p",
            postgres_port,
            "-U",
            postgres_user,
            database_name,
        ]
    )
    run_command(
        [
            "createdb",
            "-h",
            postgres_host,
            "-p",
            postgres_port,
            "-U",
            postgres_user,
            database_name,
        ]
    )
    run_command(
        [
            "pg_restore",
            "-h",
            postgres_host,
            "-p",
            postgres_port,
            "-U",
            postgres_user,
            "-d",
            database_name,
            "--clean",
            "--if-exists",
            "--no-owner",
            "--no-privileges",
            str(backup_path),
        ]
    )
    logger.info("Database restored from %s", backup_path)


def main() -> None:
    parser = argparse.ArgumentParser(description="Restore PostgreSQL from a local or S3 backup")
    parser.add_argument("source", help="Local path, backup filename, or S3 key")
    args = parser.parse_args()

    backup_path = resolve_source(args.source)
    restore_database(backup_path)


if __name__ == "__main__":
    main()
