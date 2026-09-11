#!/usr/bin/env python3
"""WhatsApp live-message notifier.

Listens for wacli sync --webhook POSTs and raises desktop notifications for
incoming messages via notify-send (shown by quickshell's notification daemon).
"""

import datetime
import json
import os
import re
import shutil
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = "127.0.0.1"
PORT = 51828
LOG = os.path.expanduser("~/.cache/quickshell/wa-webhook.log")
LOG_MAX = 400

if "go/bin" not in os.environ.get("PATH", ""):
    gobin = os.path.expanduser("~/go/bin")
    os.environ["PATH"] = os.environ.get("PATH", "") + os.pathsep + gobin

NOTIFY = shutil.which("notify-send")
ICON = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "assets", "whatsapp.png"
)


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
            length = int(self.headers.get("Content-Length") or 0)
            body = self.rfile.read(length)
            msg = json.loads(body or b"{}")
            self._log(msg)
            self.notify(msg)
        except Exception:
            pass
        try:
            self.send_response(204)
            self.end_headers()
        except Exception:
            pass

    def _log(self, msg):
        try:
            ts = datetime.datetime.now().strftime("%H:%M:%S")
            line = "%s chat=%s FromMe=%s text=%r\n" % (
                ts,
                msg.get("Chat") or "",
                msg.get("FromMe"),
                (msg.get("Text") or "")[:80],
            )
            with open(LOG, "a") as f:
                f.write(line)
            with open(LOG) as f:
                lines = f.readlines()[-LOG_MAX:]
            with open(LOG, "w") as f:
                f.writelines(lines)
        except Exception:
            pass

    def notify(self, msg):
        if not msg or msg.get("FromMe") is True:
            return
        chat = msg.get("Chat") or ""
        if chat.lower().endswith(".g.us"):
            return  # no notifications for group chats
        text = (msg.get("Text") or "").strip()
        if not text:
            text = "[Media]" if msg.get("Media") else "[Message]"
        text = " ".join(text.split())[:220]

        title = msg.get("ChatName") or "WhatsApp"
        body = text

        if not NOTIFY:
            return
        args = [NOTIFY, "-a", "WhatsApp", "-i", ICON, "-t", "12000", "-u", "normal"]
        try:
            subprocess.Popen(
                args + [title, body], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
        except Exception:
            pass

    def log_message(self, *args):
        pass


def main():
    try:
        srv = ThreadingHTTPServer((HOST, PORT), Handler)
    except OSError:
        return 0  # already running from a previous session
    srv.daemon_threads = True
    srv.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main())