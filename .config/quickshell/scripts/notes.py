#!/usr/bin/env python3
import json
import os
import sys
import time
import tempfile
import subprocess

DATA_HOME = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
STORE = os.path.join(DATA_HOME, "quickshell", "notes.json")


def load():
    try:
        with open(STORE, "r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        return []
    if not isinstance(data, list) or any(
        not isinstance(n, dict)
        or not isinstance(n.get("id"), str)
        or not isinstance(n.get("text"), str)
        for n in data
    ):
        raise ValueError("invalid notes store: " + STORE)
    return data


def save(notes):
    os.makedirs(os.path.dirname(STORE), exist_ok=True)
    tmp = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=os.path.dirname(STORE),
            prefix=".notes-", delete=False
        ) as f:
            tmp = f.name
            json.dump(notes, f, ensure_ascii=False, indent=2)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, STORE)
    finally:
        if tmp is not None and os.path.exists(tmp):
            os.unlink(tmp)


def print_error(msg):
    sys.stderr.write(msg + "\n")


def main():
    if len(sys.argv) < 2:
        print_error("usage: notes.py <list|add|delete|copy|clear>")
        return 1

    cmd = sys.argv[1]

    if cmd == "list":
        for n in load():
            print(json.dumps(n, ensure_ascii=False))
        return 0

    if cmd == "add":
        text = (sys.argv[2] if len(sys.argv) > 2 else "").strip()
        if not text:
            return 0
        notes = load()
        notes.insert(0, {
            "id": str(int(time.time() * 1000)),
            "ts": time.strftime("%b %d %H:%M"),
            "text": text,
        })
        save(notes)
        return 0

    if cmd == "delete":
        nid = sys.argv[2] if len(sys.argv) > 2 else ""
        notes = [n for n in load() if n.get("id") != nid]
        save(notes)
        return 0

    if cmd == "copy":
        nid = sys.argv[2] if len(sys.argv) > 2 else ""
        for n in load():
            if n.get("id") == nid:
                subprocess.run(["wl-copy"], input=n.get("text", "").encode("utf-8"), check=True)
                return 0
        return 1

    if cmd == "clear":
        save([])
        return 0

    print_error("unknown command: " + cmd)
    return 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.CalledProcessError) as e:
        print_error(str(e))
        sys.exit(1)