#!/usr/bin/env python3
"""Detect the TUI title reset, which precedes Codex's lazy SessionStart hook."""
import fcntl
import json
import os
from pathlib import Path
import re
import socket
import sys
import tempfile
import time

CONNECTION = None


def rpc(method, params):
    client = CONNECTION or socket.socket(socket.AF_UNIX)
    try:
        client.settimeout(3)
        if CONNECTION is None:
            client.connect(os.environ.get("CMUX_SOCKET_PATH", "/tmp/cmux.sock"))
        client.sendall((json.dumps({"id": "title-watch", "method": method,
                                   "params": params}) + "\n").encode())
        with client.makefile("rb") as stream:
            response = json.loads(stream.readline())
    finally:
        if CONNECTION is None:
            client.close()
    if not response.get("ok"):
        raise OSError("cmux request failed")
    return response["result"]


def check(path, armed):
    entry = json.loads(path.read_text())
    prefix = Path(str(path).removesuffix(".watch.json"))
    owner = Path(str(prefix) + ".session")
    identity = "Codex:" + entry["session_id"]
    if not owner.exists() or owner.read_text().strip() != identity:
        path.unlink(missing_ok=True)
        return
    workspace, surface = entry["workspace"], entry["surface"]
    surfaces = rpc("surface.list", {"workspace_id": workspace})["surfaces"]
    match = next((s for s in surfaces if s["id"] == surface), None)
    if match is None:
        path.unlink(missing_ok=True)
        return
    title = re.sub(r"^[\u2800-\u28ff]\s*", "", match.get("title", "")).strip()
    key = (workspace, entry["session_id"])
    directory = Path(entry["cwd"]).name
    if title.endswith(" | " + directory):
        armed.add(key)
        return
    if key not in armed or title != directory:
        return
    # Verify the reset is a fresh Codex screen, not a shell with the same title.
    screen = rpc("surface.read_text", {"workspace_id": workspace,
                                      "surface_id": surface, "scrollback": False})["text"]
    if "OpenAI Codex" not in screen or "100% left" not in screen:
        return
    if owner.read_text().strip() != identity:
        return
    rows = rpc("workspace.list", {})["workspaces"]
    row = next(w for w in rows if w["id"] == workspace)
    if not re.match(r"^(?:\d+:)?Codex ", row["title"]):
        return
    # Invalidate pending summaries before changing the visible title.
    owner.write_text("Codex:cleared\n")
    Path(str(prefix) + ".codex.json").unlink(missing_ok=True)
    rpc("workspace.rename", {"workspace_id": workspace,
                             "title": f"{row['index'] + 1}:Codex 待機"})
    path.unlink(missing_ok=True)
    armed.discard(key)


def main():
    root = Path(tempfile.gettempdir())
    with (root / "cmux_codex_title_watch.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        armed = set()
        failures = 0
        while True:
            paths = list(root.glob("cmux_tab_title_*.watch.json"))
            if not paths:
                return
            for path in paths:
                try:
                    check(path, armed)
                    failures = 0
                except (OSError, ValueError, KeyError, StopIteration):
                    failures += 1
            if failures >= 30:
                return
            time.sleep(1)


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--socket-fd":
        CONNECTION = socket.socket(fileno=int(sys.argv[2]))
    main()
