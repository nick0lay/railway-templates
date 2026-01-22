"""Configuration management for MinIO bucket initialization."""

import os
from typing import Optional


class Config:
    """Configuration loaded from environment variables."""

    def __init__(self):
        # MinIO connection settings
        self.minio_endpoint: str = os.getenv("MINIO_ENDPOINT", "")
        self.minio_access_key: str = os.getenv("MINIO_ACCESS_KEY", "")
        self.minio_secret_key: str = os.getenv("MINIO_SECRET_KEY", "")
        self.minio_secure: bool = os.getenv("MINIO_SECURE", "false").lower() == "true"

        # Bucket configuration
        self.minio_bucket: str = os.getenv("MINIO_BUCKET", "")

        # Controller settings
        self.is_active: bool = os.getenv("IS_ACTIVE", "true").lower() == "true"
        self.auto_disable: bool = os.getenv("AUTO_DISABLE", "true").lower() == "true"
        self.check_interval: int = int(os.getenv("CHECK_INTERVAL", "1"))
        self.healthy_cycles_threshold: int = int(
            os.getenv("HEALTHY_CYCLES_THRESHOLD", "3")
        )

        # State file location
        self.state_file: str = os.getenv("STATE_FILE", "/app/state.json")

    def get_bucket(self) -> str:
        """Return the bucket name (trimmed)."""
        return self.minio_bucket.strip()

    def validate(self) -> tuple[bool, Optional[str]]:
        """Validate required configuration fields.

        Returns:
            tuple: (is_valid, error_message)
        """
        if not self.minio_endpoint:
            return False, "MINIO_ENDPOINT is required"
        if not self.minio_access_key:
            return False, "MINIO_ACCESS_KEY is required"
        if not self.minio_secret_key:
            return False, "MINIO_SECRET_KEY is required"
        if not self.get_bucket():
            return False, "MINIO_BUCKET is required"
        return True, None

    def __repr__(self) -> str:
        return (
            f"Config(endpoint={self.minio_endpoint}, "
            f"bucket={self.get_bucket()}, "
            f"is_active={self.is_active}, "
            f"auto_disable={self.auto_disable})"
        )
