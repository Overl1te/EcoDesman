from __future__ import annotations

import os

import boto3
from botocore.config import Config


def env_str(name: str, default: str = "") -> str:
    return os.getenv(name, default).strip()


def s3_is_configured() -> bool:
    return all(
        (
            env_str("AWS_STORAGE_BUCKET_NAME"),
            env_str("AWS_S3_ENDPOINT_URL"),
            env_str("AWS_S3_ACCESS_KEY_ID"),
            env_str("AWS_S3_SECRET_ACCESS_KEY"),
        )
    )


def get_backup_bucket_name() -> str:
    return env_str("BACKUP_S3_BUCKET_NAME") or env_str("AWS_STORAGE_BUCKET_NAME")


def get_backup_prefix() -> str:
    return env_str("BACKUP_S3_PREFIX", "ops").strip("/")


def build_s3_client():
    if not s3_is_configured():
        return None

    config = Config(
        signature_version=env_str("AWS_S3_SIGNATURE_VERSION", "s3v4"),
        s3={
            "addressing_style": env_str("AWS_S3_ADDRESSING_STYLE", "path"),
        },
    )
    client_kwargs: dict[str, object] = {
        "service_name": "s3",
        "endpoint_url": env_str("AWS_S3_ENDPOINT_URL"),
        "aws_access_key_id": env_str("AWS_S3_ACCESS_KEY_ID"),
        "aws_secret_access_key": env_str("AWS_S3_SECRET_ACCESS_KEY"),
        "config": config,
    }
    region_name = env_str("AWS_S3_REGION_NAME")
    verify = env_str("AWS_S3_VERIFY")
    if region_name:
        client_kwargs["region_name"] = region_name
    if verify:
        client_kwargs["verify"] = verify
    return boto3.client(**client_kwargs)
