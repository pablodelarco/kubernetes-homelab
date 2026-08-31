#!/usr/bin/env python3
"""Install or repair native Garage object storage on the UGREEN DH2300.

The script is idempotent. It never overwrites an existing Garage configuration
or credential environment file, so rerunning it after an UGOS update preserves
the object store identity and Longhorn credentials.
"""

from __future__ import annotations

import base64
import grp
import hashlib
import os
from pathlib import Path
import pwd
import secrets
import shutil
import subprocess
import tempfile
import time
import urllib.request

VERSION = "2.3.0"
DOWNLOAD_URL = (
    "https://garagehq.deuxfleurs.fr/_releases/v2.3.0/"
    "aarch64-unknown-linux-musl/garage"
)
EXPECTED_SHA256 = "8ced2ad3040262571de08aa600959aa51f97576d55da7946fcde6f66140705e2"
TAILSCALE_IP = "100.96.235.59"
SERVICE_USER = "garage"
SERVICE_GROUP = "garage"
SERVICE_UID = 3900
SERVICE_GID = 3900
BASE = Path("/volume1/.services/garage")
BIN_DIR = BASE / "bin"
ETC_DIR = BASE / "etc"
META_DIR = BASE / "meta"
DATA_DIR = BASE / "data"
SNAPSHOT_DIR = BASE / "snapshots"
CONFIG_PATH = ETC_DIR / "garage.toml"
ENV_PATH = ETC_DIR / "default.env"
VERSIONED_BINARY = BIN_DIR / f"garage-v{VERSION}"
CURRENT_BINARY = BIN_DIR / "garage"
UNIT_PATH = Path("/etc/systemd/system/garage-nas.service")


def run(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=check, text=True, capture_output=True)


def atomic_write(path: Path, content: str, mode: int, uid: int, gid: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary_path = Path(temporary)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary_path, mode)
        os.chown(temporary_path, uid, gid)
        os.replace(temporary_path, path)
    finally:
        temporary_path.unlink(missing_ok=True)


def ensure_identity() -> None:
    try:
        existing_group = grp.getgrnam(SERVICE_GROUP)
        if existing_group.gr_gid != SERVICE_GID:
            raise RuntimeError(
                f"Group {SERVICE_GROUP} exists with GID {existing_group.gr_gid}, expected {SERVICE_GID}"
            )
    except KeyError:
        if any(entry.gr_gid == SERVICE_GID for entry in grp.getgrall()):
            raise RuntimeError(f"GID {SERVICE_GID} is already in use")
        run("groupadd", "--gid", str(SERVICE_GID), SERVICE_GROUP)

    try:
        existing_user = pwd.getpwnam(SERVICE_USER)
        if existing_user.pw_uid != SERVICE_UID or existing_user.pw_gid != SERVICE_GID:
            raise RuntimeError(
                f"User {SERVICE_USER} exists with UID:GID "
                f"{existing_user.pw_uid}:{existing_user.pw_gid}, expected {SERVICE_UID}:{SERVICE_GID}"
            )
    except KeyError:
        if any(entry.pw_uid == SERVICE_UID for entry in pwd.getpwall()):
            raise RuntimeError(f"UID {SERVICE_UID} is already in use")
        nologin = shutil.which("nologin") or "/usr/sbin/nologin"
        run(
            "useradd",
            "--uid",
            str(SERVICE_UID),
            "--gid",
            str(SERVICE_GID),
            "--home-dir",
            str(BASE),
            "--no-create-home",
            "--shell",
            nologin,
            "--comment",
            "Garage object storage",
            SERVICE_USER,
        )


def ensure_directories() -> None:
    BASE.mkdir(parents=True, exist_ok=True)
    for path in (META_DIR, DATA_DIR, SNAPSHOT_DIR):
        path.mkdir(parents=True, exist_ok=True)
        os.chown(path, SERVICE_UID, SERVICE_GID)
        os.chmod(path, 0o700)

    for path in (BIN_DIR, ETC_DIR):
        path.mkdir(parents=True, exist_ok=True)
        os.chown(path, 0, SERVICE_GID)
        os.chmod(path, 0o750)

    os.chown(BASE, SERVICE_UID, SERVICE_GID)
    os.chmod(BASE, 0o750)


def ensure_binary() -> None:
    valid_existing = False
    if VERSIONED_BINARY.exists():
        digest = hashlib.sha256(VERSIONED_BINARY.read_bytes()).hexdigest()
        valid_existing = digest == EXPECTED_SHA256

    if not valid_existing:
        fd, temporary = tempfile.mkstemp(prefix="garage-download-", dir=BIN_DIR)
        os.close(fd)
        temporary_path = Path(temporary)
        try:
            with urllib.request.urlopen(DOWNLOAD_URL, timeout=180) as source, temporary_path.open("wb") as target:
                shutil.copyfileobj(source, target)
                target.flush()
                os.fsync(target.fileno())
            digest = hashlib.sha256(temporary_path.read_bytes()).hexdigest()
            if digest != EXPECTED_SHA256:
                raise RuntimeError(f"Garage SHA256 mismatch: {digest}")
            os.chown(temporary_path, 0, 0)
            os.chmod(temporary_path, 0o755)
            os.replace(temporary_path, VERSIONED_BINARY)
        finally:
            temporary_path.unlink(missing_ok=True)

    version = run(str(VERSIONED_BINARY), "--version").stdout.strip()
    if f"v{VERSION}" not in version:
        raise RuntimeError(f"Unexpected Garage version: {version}")

    if CURRENT_BINARY.is_symlink() or CURRENT_BINARY.exists():
        CURRENT_BINARY.unlink()
    CURRENT_BINARY.symlink_to(VERSIONED_BINARY.name)


def ensure_config() -> None:
    if not CONFIG_PATH.exists():
        rpc_secret = secrets.token_hex(32)
        admin_token = base64.b64encode(os.urandom(32)).decode("ascii")
        metrics_token = base64.b64encode(os.urandom(32)).decode("ascii")
        config = f'''metadata_dir = "{META_DIR}"
data_dir = "{DATA_DIR}"
metadata_snapshots_dir = "{SNAPSHOT_DIR}"
metadata_fsync = true
data_fsync = true
disable_scrub = false
metadata_auto_snapshot_interval = "6h"

db_engine = "sqlite"
block_size = "1M"
block_ram_buffer_max = "128MiB"
compression_level = 1

replication_factor = 1
consistency_mode = "consistent"

rpc_bind_addr = "127.0.0.1:3901"
rpc_public_addr = "127.0.0.1:3901"
rpc_secret = "{rpc_secret}"
allow_world_readable_secrets = false

[s3_api]
s3_region = "us-east-1"
api_bind_addr = "{TAILSCALE_IP}:3900"
root_domain = ".s3.garage.homelab"

[admin]
api_bind_addr = "{TAILSCALE_IP}:3903"
admin_token = "{admin_token}"
metrics_token = "{metrics_token}"
metrics_require_token = true
'''
        atomic_write(CONFIG_PATH, config, 0o640, 0, SERVICE_GID)

    if not ENV_PATH.exists():
        access_key = "GK" + secrets.token_hex(16)
        secret_key = secrets.token_hex(32)
        environment = (
            f"GARAGE_DEFAULT_ACCESS_KEY={access_key}\n"
            f"GARAGE_DEFAULT_SECRET_KEY={secret_key}\n"
            "GARAGE_DEFAULT_BUCKET=k8s-backups\n"
        )
        atomic_write(ENV_PATH, environment, 0o640, 0, SERVICE_GID)


def ensure_unit() -> None:
    unit = f'''[Unit]
Description=Garage S3 object storage on local NAS RAID1
Documentation=https://garagehq.deuxfleurs.fr/documentation/
Wants=network-online.target tailscaled.service
After=network-online.target tailscaled.service
RequiresMountsFor=/volume1

[Service]
Type=simple
User={SERVICE_USER}
Group={SERVICE_GROUP}
UMask=0077
EnvironmentFile={ENV_PATH}
Environment=RUST_LOG=garage=info
Environment=RUST_BACKTRACE=1
Environment=GARAGE_LOG_TO_JOURNALD=true
ExecStart={CURRENT_BINARY} -c {CONFIG_PATH} server --single-node --default-bucket
Restart=always
RestartSec=5s
TimeoutStopSec=120s
LimitNOFILE=65536
MemoryMax=1G
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths={BASE}
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
RestrictSUIDSGID=true
LockPersonality=true

[Install]
WantedBy=multi-user.target
'''
    atomic_write(UNIT_PATH, unit, 0o644, 0, 0)
    run("systemctl", "daemon-reload")
    run("systemctl", "enable", "--now", "garage-nas.service")


def verify() -> None:
    deadline = time.monotonic() + 30
    active = ""
    enabled = ""
    status = ""
    last_error = ""
    while time.monotonic() < deadline:
        active = run("systemctl", "is-active", "garage-nas.service", check=False).stdout.strip()
        enabled = run("systemctl", "is-enabled", "garage-nas.service", check=False).stdout.strip()
        result = run(str(CURRENT_BINARY), "-c", str(CONFIG_PATH), "status", check=False)
        status = result.stdout
        last_error = result.stderr.strip()
        if active == "active" and enabled == "enabled" and "HEALTHY NODES" in status:
            break
        time.sleep(1)
    else:
        raise RuntimeError(
            f"Garage verification failed: active={active!r}, enabled={enabled!r}, "
            f"status_error={last_error!r}"
        )
    print(f"garage_version={VERSION}")
    print(f"service_active={active}")
    print(f"service_enabled={enabled}")
    print("bucket=k8s-backups")
    print("credentials_preserved=true")


def main() -> None:
    if os.geteuid() != 0:
        raise SystemExit("Run as root")
    if os.uname().machine not in {"aarch64", "arm64"}:
        raise SystemExit(f"Unsupported architecture: {os.uname().machine}")
    if not Path("/volume1").is_mount():
        raise SystemExit("/volume1 is not mounted")

    ensure_identity()
    ensure_directories()
    ensure_binary()
    ensure_config()
    ensure_unit()
    verify()


if __name__ == "__main__":
    main()
