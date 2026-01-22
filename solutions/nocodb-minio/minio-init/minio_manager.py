"""MinIO operations with retry logic for bucket management."""

import time
from typing import Optional

from minio import Minio
from minio.error import S3Error

from config import Config


class MinioManager:
    """Manages MinIO bucket operations with retry logic."""

    def __init__(self, config: Config):
        self.config = config
        self.client: Optional[Minio] = None

    def _create_client(self) -> Minio:
        """Create a new MinIO client instance."""
        return Minio(
            endpoint=self.config.minio_endpoint,
            access_key=self.config.minio_access_key,
            secret_key=self.config.minio_secret_key,
            secure=self.config.minio_secure,
        )

    def wait_for_minio(self, max_retries: int = 30, base_delay: float = 2.0) -> bool:
        """Wait for MinIO to be ready with exponential backoff.

        Args:
            max_retries: Maximum number of retry attempts
            base_delay: Base delay in seconds (doubles each retry, capped at 60s)

        Returns:
            bool: True if MinIO is ready, False if max retries exceeded
        """
        delay = base_delay
        max_delay = 60.0

        for attempt in range(1, max_retries + 1):
            try:
                self.client = self._create_client()
                # Try to list buckets as a connectivity test
                self.client.list_buckets()
                print(f"✓ Connected to MinIO at {self.config.minio_endpoint}")
                return True
            except Exception as e:
                print(
                    f"⏳ Waiting for MinIO (attempt {attempt}/{max_retries}): {type(e).__name__}"
                )
                if attempt < max_retries:
                    time.sleep(delay)
                    delay = min(delay * 2, max_delay)

        print(f"✗ Failed to connect to MinIO after {max_retries} attempts")
        return False

    def bucket_exists(self, bucket_name: str) -> bool:
        """Check if a bucket exists.

        Args:
            bucket_name: Name of the bucket to check

        Returns:
            bool: True if bucket exists, False otherwise
        """
        if not self.client:
            return False
        try:
            return self.client.bucket_exists(bucket_name)
        except S3Error as e:
            print(f"✗ Error checking bucket '{bucket_name}': {e}")
            return False

    def create_bucket(self, bucket_name: str) -> bool:
        """Create a bucket if it doesn't exist (idempotent).

        Args:
            bucket_name: Name of the bucket to create

        Returns:
            bool: True if bucket exists or was created, False on error
        """
        if not self.client:
            print("✗ MinIO client not initialized")
            return False

        try:
            if self.client.bucket_exists(bucket_name):
                print(f"• Bucket '{bucket_name}' already exists")
                return True

            self.client.make_bucket(bucket_name)
            print(f"✓ Created bucket '{bucket_name}'")
            return True
        except S3Error as e:
            print(f"✗ Error creating bucket '{bucket_name}': {e}")
            return False

    def ensure_bucket_exists(self, bucket_name: str) -> bool:
        """Ensure the specified bucket exists.

        Args:
            bucket_name: Name of the bucket to create

        Returns:
            bool: True if bucket exists or was created successfully
        """
        return self.create_bucket(bucket_name)

    def verify_bucket(self, bucket_name: str) -> bool:
        """Verify the specified bucket exists.

        Args:
            bucket_name: Name of the bucket to verify

        Returns:
            bool: True if bucket exists
        """
        return self.bucket_exists(bucket_name)
