#!/usr/bin/env python3
"""MinIO bucket initialization controller for Railway deployments."""

import json
import os
import signal
import sys
import time
from datetime import datetime
from typing import Any

from config import Config
from minio_manager import MinioManager


class MinioInitController:
    """Main controller for MinIO bucket initialization."""

    def __init__(self, config: Config):
        self.config = config
        self.minio_manager = MinioManager(config)
        self.running = True
        self.state = self._load_state()

        # Register signal handlers for graceful shutdown
        signal.signal(signal.SIGTERM, self._handle_signal)
        signal.signal(signal.SIGINT, self._handle_signal)

    def _handle_signal(self, signum: int, frame: Any) -> None:
        """Handle shutdown signals gracefully."""
        sig_name = signal.Signals(signum).name
        print(f"\n⚠ Received {sig_name}, shutting down gracefully...")
        self.running = False

    def _load_state(self) -> dict:
        """Load state from file or return default state."""
        if os.path.exists(self.config.state_file):
            try:
                with open(self.config.state_file, "r") as f:
                    state = json.load(f)
                    print(f"• Loaded state from {self.config.state_file}")
                    return state
            except (json.JSONDecodeError, OSError) as e:
                print(f"⚠ Could not load state file: {e}")

        return {
            "is_disabled": False,
            "consecutive_healthy_cycles": 0,
            "last_run": None,
            "bucket_created": None,
        }

    def _save_state(self) -> None:
        """Save current state to file."""
        try:
            # Ensure directory exists
            os.makedirs(os.path.dirname(self.config.state_file), exist_ok=True)
            with open(self.config.state_file, "w") as f:
                json.dump(self.state, f, indent=2, default=str)
        except OSError as e:
            print(f"⚠ Could not save state: {e}")

    def _should_disable(self) -> bool:
        """Check if controller should auto-disable."""
        if not self.config.auto_disable:
            return False
        return (
            self.state["consecutive_healthy_cycles"]
            >= self.config.healthy_cycles_threshold
        )

    def run_initialization_cycle(self) -> bool:
        """Run one initialization cycle.

        Returns:
            bool: True if bucket exists/was created, False otherwise
        """
        bucket = self.config.get_bucket()
        print(f"\n{'='*50}")
        print(f"Initialization Cycle - {datetime.now().isoformat()}")
        print(f"Target bucket: {bucket}")
        print(f"{'='*50}")

        # Wait for MinIO to be ready
        if not self.minio_manager.wait_for_minio():
            return False

        # Create bucket
        if not self.minio_manager.ensure_bucket_exists(bucket):
            print(f"✗ Failed to create bucket: {bucket}")
            self.state["consecutive_healthy_cycles"] = 0
            return False

        # Verify bucket exists
        if not self.minio_manager.verify_bucket(bucket):
            print(f"✗ Bucket missing after creation: {bucket}")
            self.state["consecutive_healthy_cycles"] = 0
            return False

        print(f"✓ Bucket '{bucket}' verified")
        self.state["consecutive_healthy_cycles"] += 1
        self.state["last_run"] = datetime.now().isoformat()
        self.state["bucket_created"] = bucket

        return True

    def run(self) -> None:
        """Main controller loop."""
        print("\n" + "=" * 50)
        print("MinIO Bucket Initialization Controller")
        print("=" * 50)
        print(f"Config: {self.config}")

        # Validate configuration
        is_valid, error = self.config.validate()
        if not is_valid:
            print(f"✗ Configuration error: {error}")
            sys.exit(1)

        # Check if disabled
        if not self.config.is_active:
            print("• Controller is disabled (IS_ACTIVE=false)")
            return

        if self.state.get("is_disabled"):
            print("• Controller previously auto-disabled")
            print(f"  Bucket created: {self.state.get('bucket_created')}")
            print("  Set IS_ACTIVE=false or delete state file to re-enable")
            return

        # Main monitoring loop
        while self.running:
            success = self.run_initialization_cycle()
            self._save_state()

            if success and self._should_disable():
                print("\n" + "=" * 50)
                print("✓ Auto-disabling after successful initialization")
                print(f"  Healthy cycles: {self.state['consecutive_healthy_cycles']}")
                print(f"  Bucket created: {self.state['bucket_created']}")
                print("=" * 50)
                self.state["is_disabled"] = True
                self._save_state()
                break

            if self.running:
                print(
                    f"\n• Next check in {self.config.check_interval} minute(s)..."
                )
                print(
                    f"  Healthy cycles: {self.state['consecutive_healthy_cycles']}"
                    f"/{self.config.healthy_cycles_threshold}"
                )
                time.sleep(self.config.check_interval * 60)

        print("\n• Controller stopped")


def main() -> None:
    """Entry point."""
    config = Config()
    controller = MinioInitController(config)
    controller.run()


if __name__ == "__main__":
    main()
