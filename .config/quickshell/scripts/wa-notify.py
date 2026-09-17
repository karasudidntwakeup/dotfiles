#!/usr/bin/env python3
"""WhatsApp live-message notifier.

Listens for wacli sync --webhook POSTs and raises desktop notifications for
incoming messages via notify-send (shown by quickshell's notification daemon).
"""

import html
import glob
import json
import os
import re
import shutil
import socket
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = "127.0.0.1"
PORT = 51828
MAX_BODY = 256 * 1024
DIRECT_JID = re.compile(r"[0-9]{1,32}@(s\.whatsapp\.net|lid)")


if "go/bin" not in os.environ.get("PATH", ""):
    gobin = os.path.expanduser("~/go/bin")
    os.environ["PATH"] = os.environ.get("PATH", "") + os.pathsep + gobin

NOTIFY = shutil.which("notify-send")
ICON = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "assets", "whatsapp.png"
)
BUS_FILE = os.path.expanduser("~/.cache/quickshell/wa-session.env")


def bus_alive(addr):
    if not addr:
        return False
    try:
        if addr.startswith("unix:path="):
            path = addr[len("unix:path="):].split(",", 1)[0]
        elif addr.startswith("unix:abstract="):
            path = "\0" + addr[len("unix:abstract="):].split(",", 1)[0]
        else:
            return False
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            s.settimeout(0.5)
            s.connect(path)
            return True
        finally:
            s.close()
    except Exception:
        return False


def session_bus():
    """Current D-Bus session address, refreshing stale ones at runtime.

    Long-lived processes keep a session-bus address that dies whenever the
    compositor session restarts; the watcher records a fresh one per session,
    and as a last resort we connect-probe /tmp/dbus-* sockets (stale daemons
    reject the connect, the live one accepts).
    """
    candidates = [os.environ.get("DBUS_SESSION_BUS_ADDRESS")]
    try:
        with open(BUS_FILE) as f:
            raw = f.read().strip()
        if "=" in raw:
            candidates.append(raw.split("=", 1)[1])
    except Exception:
        pass
    for c in candidates:
        if bus_alive(c):
            return c
    for fn in sorted(glob.glob("/tmp/dbus-*"), key=os.path.getmtime, reverse=True):
        addr = "unix:path=" + fn
        if bus_alive(addr):
            return addr
    return os.environ.get("DBUS_SESSION_BUS_ADDRESS")


def contact_name(jid, cache):
    """Best-effort display name for a contact JID (lazily cached)."""
    if jid in cache:
        return cache[jid]
    name = ""
    phone = re.sub(r"[@:].*$", "", jid or "")
    if phone and phone != "0":
        try:
            out = subprocess.run(
                ["wacli", "--json", "contacts", "search", phone, "--limit", "1"],
                capture_output=True,
                text=True,
                timeout=4,
            )
            data = json.loads(out.stdout or "{}")
            rows = (data or {}).get("data") or []
            if rows and rows[0].get("name"):
                name = rows[0]["name"]
        except Exception:
            pass
    cache[jid] = name
    return name


class Handler(BaseHTTPRequestHandler):
    cache = {}

    def do_POST(self):
        try:
            raw = self.headers.get("Content-Length")
            if raw is None:
                raise ValueError
            length = int(raw)
            if length < 0 or length > MAX_BODY:
                self.close_connection = True
                self.send_response(413)
                self.end_headers()
                return
            self.connection.settimeout(5)
            body = self.rfile.read(length)
            msg = json.loads(body or b"{}")
            self.notify(msg)
        except Exception:
            pass
        try:
            self.send_response(204)
            self.end_headers()
        except Exception:
            pass

    def notify(self, msg):
        if not msg or msg.get("FromMe") is True:
            return
        chat = msg.get("Chat") or ""
        if not DIRECT_JID.fullmatch(chat):
            return
        text = (msg.get("Text") or "").strip()
        if not text:
            text = "[Media]" if msg.get("Media") else "[Message]"
        text = " ".join(text.split())[:220]

        title = html.escape(msg.get("ChatName") or "WhatsApp")
        body = html.escape(text)

        if not NOTIFY:
            return
        args = [NOTIFY, "-a", "WhatsApp", "-i", ICON, "-t", "12000", "-u", "normal"]
        try:
            env = dict(os.environ)
            bus = session_bus()
            if bus:
                env["DBUS_SESSION_BUS_ADDRESS"] = bus
            subprocess.Popen(
                args + ["--", title, body],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                env=env,
            )
        except Exception:
            pass

    def log_message(self, *args):
        pass


def main():
    try:
        srv = ThreadingHTTPServer((HOST, PORT), Handler)
    except OSError:
        return 0
    srv.daemon_threads = True
    srv.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main())