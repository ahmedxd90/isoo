"""Small, dependency-free room worker for Saki.

This service is intentionally outside the Flutter APK. It does not mutate
wallets, gifts, permissions, or room membership; Supabase RPC remains the
authoritative source for those operations.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import time
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Lock
from urllib.parse import urlparse


MAX_BODY_BYTES = 256 * 1024
ALLOWED_MEDIA_TYPES = {"gif", "mp4", "svga", "webm", "png", "jpg", "jpeg"}


class Metrics:
    def __init__(self) -> None:
        self._lock = Lock()
        self.started_at = time.time()
        self.events = 0
        self.media_inspections = 0
        self.errors = 0

    def snapshot(self) -> dict[str, int | float]:
        with self._lock:
            return {
                "uptime_seconds": int(time.time() - self.started_at),
                "events": self.events,
                "media_inspections": self.media_inspections,
                "errors": self.errors,
            }

    def increment(self, name: str) -> None:
        with self._lock:
            setattr(self, name, getattr(self, name) + 1)


METRICS = Metrics()


def normalize_event(payload: dict) -> dict:
    """Return a stable event shape for downstream workers and dashboards."""
    event_type = str(payload.get("event_type") or payload.get("type") or "unknown")
    event_id = str(payload.get("event_id") or payload.get("id") or "")
    room_id = str(payload.get("room_id") or "")
    return {
        "event_id": event_id,
        "event_type": event_type,
        "room_id": room_id,
        "received_at": time.time(),
        "payload": payload,
    }


def inspect_media(path_value: str) -> dict:
    path = Path(path_value).expanduser().resolve()
    suffix = path.suffix.lower().lstrip(".")
    result: dict[str, object] = {
        "path": str(path),
        "exists": path.is_file(),
        "type": suffix or "unknown",
        "size_bytes": path.stat().st_size if path.is_file() else 0,
    }
    if suffix not in ALLOWED_MEDIA_TYPES:
        result["supported"] = False
        result["reason"] = "unsupported_extension"
        return result
    result["supported"] = path.is_file()
    ffprobe = shutil.which("ffprobe")
    if path.is_file() and ffprobe and suffix in {"mp4", "webm", "gif", "mov"}:
        try:
            command = [
                ffprobe,
                "-v", "error",
                "-show_entries", "format=duration:stream=width,height,codec_name",
                "-of", "json",
                str(path),
            ]
            completed = subprocess.run(
                command, check=True, capture_output=True, text=True, timeout=8
            )
            result["ffprobe"] = json.loads(completed.stdout)
        except (OSError, subprocess.SubprocessError, json.JSONDecodeError) as error:
            result["ffprobe_error"] = type(error).__name__
    return result


class Handler(BaseHTTPRequestHandler):
    server_version = "SakiRoomWorker/1.0"

    def _write(self, status: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0 or length > MAX_BODY_BYTES:
            raise ValueError("invalid_body_size")
        raw = self.rfile.read(length)
        value = json.loads(raw.decode("utf-8"))
        if not isinstance(value, dict):
            raise ValueError("json_object_required")
        return value

    def do_GET(self) -> None:  # noqa: N802
        route = urlparse(self.path).path
        if route == "/health":
            self._write(HTTPStatus.OK, {"ok": True, "service": "room_worker"})
            return
        if route == "/metrics":
            self._write(HTTPStatus.OK, {"ok": True, "metrics": METRICS.snapshot()})
            return
        self._write(HTTPStatus.NOT_FOUND, {"ok": False, "error": "not_found"})

    def do_POST(self) -> None:  # noqa: N802
        route = urlparse(self.path).path
        try:
            payload = self._read_json()
            if route == "/events/normalize":
                METRICS.increment("events")
                self._write(HTTPStatus.OK, {"ok": True, "event": normalize_event(payload)})
                return
            if route == "/media/inspect":
                METRICS.increment("media_inspections")
                path = str(payload.get("path") or "")
                if not path:
                    raise ValueError("path_required")
                self._write(HTTPStatus.OK, {"ok": True, "media": inspect_media(path)})
                return
            self._write(HTTPStatus.NOT_FOUND, {"ok": False, "error": "not_found"})
        except (ValueError, json.JSONDecodeError) as error:
            METRICS.increment("errors")
            self._write(HTTPStatus.BAD_REQUEST, {"ok": False, "error": str(error)})
        except Exception:
            METRICS.increment("errors")
            self._write(HTTPStatus.INTERNAL_SERVER_ERROR, {"ok": False, "error": "internal_error"})

    def log_message(self, _format: str, *_args: object) -> None:
        return


def main() -> None:
    host = os.getenv("SAKI_WORKER_HOST", "127.0.0.1")
    port = int(os.getenv("SAKI_WORKER_PORT", "8787"))
    server = ThreadingHTTPServer((host, port), Handler)
    print(f"Saki room worker listening on http://{host}:{port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
