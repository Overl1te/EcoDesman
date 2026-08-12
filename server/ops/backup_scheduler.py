from __future__ import annotations

import os
import time
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from ops.run_backup import execute_backup, logger


def env_str(name: str, default: str = "") -> str:
    return os.getenv(name, default).strip()


def env_bool(name: str, default: bool = False) -> bool:
    return env_str(name, str(default)).lower() in {"1", "true", "yes", "on"}


def env_int(name: str, default: int) -> int:
    try:
        return int(env_str(name, str(default)))
    except ValueError:
        return default


def get_timezone() -> ZoneInfo:
    return ZoneInfo(env_str("BACKUP_TIMEZONE", "Europe/Moscow"))


def sleep_until_next_run() -> None:
    tz = get_timezone()
    now = datetime.now(tz)
    next_run = now.replace(
        hour=max(0, min(env_int("BACKUP_SCHEDULE_HOUR", 3), 23)),
        minute=max(0, min(env_int("BACKUP_SCHEDULE_MINUTE", 0), 59)),
        second=0,
        microsecond=0,
    )
    if next_run <= now:
        next_run += timedelta(days=1)

    wait_seconds = max((next_run - now).total_seconds(), 1)
    logger.info("Next backup scheduled for %s", next_run.isoformat())
    time.sleep(wait_seconds)


def main() -> None:
    if env_bool("BACKUP_RUN_ON_START", default=False):
        execute_backup()

    while True:
        sleep_until_next_run()
        execute_backup()


if __name__ == "__main__":
    main()
