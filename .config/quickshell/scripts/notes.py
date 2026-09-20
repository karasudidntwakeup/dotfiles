#!/usr/bin/env python3
"""Sticky-notes store for Quickshell.

Each note: {id, title, text, color, pinned, ts, updated,
             created_ms, updated_ms}

Commands:
  list
  add <text> [title] [color]
  update <id> <text> [title] [color]
  toggle-pin <id> | pin <id> | unpin <id>
  set-color <id> <color>
  duplicate <id>
  delete <id>
  copy <id>            (copies to clipboard via wl-copy)
  clear
"""
import json
import os
import sys
import time
import tempfile
import subprocess

DATA_HOME = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
STORE = os.path.join(DATA_HOME, "quickshell", "notes.json")

VALID_COLORS = ("yellow", "pink", "mint", "sky", "lilac", "peach")
DEFAULT_COLOR = "yellow"


def now_ms():
    return int(time.time() * 1000)


def fmt_ts(ms=None):
    t = time.localtime((ms / 1000.0) if ms else time.time())
    return time.strftime("%b %d %H:%M", t)


def normalize(note):
    """Migrate legacy / partial entries to the full schema."""
    if not isinstance(note, dict):
        return None
    nid = note.get("id")
    text = note.get("text", "")
    if not isinstance(nid, str) or not nid:
        return None
    if not isinstance(text, str):
        text = str(text)
    title = note.get("title", "")
    if not isinstance(title, str):
        title = str(title)
    color = note.get("color", DEFAULT_COLOR)
    if color not in VALID_COLORS:
        color = DEFAULT_COLOR
    try:
        created = int(note.get("created_ms") or 0)
    except (TypeError, ValueError):
        created = 0
    try:
        updated = int(note.get("updated_ms") or 0)
    except (TypeError, ValueError):
        updated = 0
    if created <= 0:
        # Derive a stable order from legacy numeric ids when possible.
        try:
            created = int(nid)
        except ValueError:
            created = now_ms()
    if updated <= 0:
        updated = created
    ts = note.get("ts") if isinstance(note.get("ts"), str) and note.get("ts") else fmt_ts(created)
    upd = note.get("updated") if isinstance(note.get("updated"), str) and note.get("updated") else ts
    return {
        "id": nid,
        "title": title,
        "text": text,
        "color": color,
        "pinned": bool(note.get("pinned")),
        "ts": ts,
        "updated": upd,
        "created_ms": created,
        "updated_ms": updated,
    }


def load():
    try:
        with open(STORE, "r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        return []
    if not isinstance(data, list):
        raise ValueError("invalid notes store: " + STORE)
    notes = []
    for n in data:
        norm = normalize(n)
        if norm is not None:
            notes.append(norm)
    return notes


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


def find(notes, nid):
    for n in notes:
        if n.get("id") == nid:
            return n
    return None


def sort_notes(notes):
    notes.sort(key=lambda n: (not n.get("pinned", False), -(n.get("updated_ms") or 0)))


def valid_color(c):
    return c if c in VALID_COLORS else DEFAULT_COLOR


def print_error(msg):
    sys.stderr.write(msg + "\n")


def main():
    if len(sys.argv) < 2:
        print_error("usage: notes.py <list|add|update|toggle-pin|pin|unpin|"
                    "set-color|duplicate|delete|copy|clear>")
        return 1

    cmd = sys.argv[1]

    if cmd == "list":
        for n in load():
            print(json.dumps(n, ensure_ascii=False))
        return 0

    if cmd == "add":
        text = (sys.argv[2] if len(sys.argv) > 2 else "").strip()
        title = (sys.argv[3] if len(sys.argv) > 3 else "").strip()
        color = valid_color((sys.argv[4] if len(sys.argv) > 4 else "").strip())
        if not text and not title:
            return 0
        ms = now_ms()
        notes = load()
        notes.insert(0, {
            "id": str(ms),
            "title": title,
            "text": text,
            "color": color,
            "pinned": False,
            "ts": fmt_ts(ms),
            "updated": fmt_ts(ms),
            "created_ms": ms,
            "updated_ms": ms,
        })
        sort_notes(notes)
        save(notes)
        return 0

    if cmd == "update":
        nid = sys.argv[2] if len(sys.argv) > 2 else ""
        text = (sys.argv[3] if len(sys.argv) > 3 else "")
        title = (sys.argv[4] if len(sys.argv) > 4 else "")
        color = (sys.argv[5] if len(sys.argv) > 5 else "")
        notes = load()
        n = find(notes, nid)
        if n is None:
            print_error("note not found: " + nid)
            return 1
        # Empty update keeps old value (lets callers pass "" to skip).
        if text != "\x00":
            n["text"] = text
        if title != "\x00":
            n["title"] = title
        if color:
            n["color"] = valid_color(color.strip())
        ms = now_ms()
        n["updated_ms"] = ms
        n["updated"] = fmt_ts(ms)
        sort_notes(notes)
        save(notes)
        return 0

    if cmd in ("toggle-pin", "pin", "unpin"):
        nid = sys.argv[2] if len(sys.argv) > 2 else ""
        notes = load()
        n = find(notes, nid)
        if n is None:
            print_error("note not found: " + nid)
            return 1
        if cmd == "toggle-pin":
            n["pinned"] = not n.get("pinned", False)
        elif cmd == "pin":
            n["pinned"] = True
        else:
            n["pinned"] = False
        sort_notes(notes)
        save(notes)
        return 0

    if cmd == "set-color":
        nid = sys.argv[2] if len(sys.argv) > 2 else ""
        color = (sys.argv[3] if len(sys.argv) > 3 else "").strip()
        if color not in VALID_COLORS:
            return 0
        notes = load()
        n = find(notes, nid)
        if n is None:
            print_error("note not found: " + nid)
            return 1
        n["color"] = color
        # Recolor is not a content edit: leave timestamps alone so the
        # card keeps its grid position instead of jumping to the top.
        save(notes)
        return 0

    if cmd == "duplicate":
        nid = sys.argv[2] if len(sys.argv) > 2 else ""
        notes = load()
        n = find(notes, nid)
        if n is None:
            print_error("note not found: " + nid)
            return 1
        ms = now_ms()
        notes.insert(0, {
            "id": str(ms),
            "title": n.get("title", ""),
            "text": n.get("text", ""),
            "color": n.get("color", DEFAULT_COLOR),
            "pinned": False,
            "ts": fmt_ts(ms),
            "updated": fmt_ts(ms),
            "created_ms": ms,
            "updated_ms": ms,
        })
        sort_notes(notes)
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
                title = (n.get("title") or "").strip()
                body = n.get("text") or ""
                payload = (title + "\n" + body).strip() if title else body
                subprocess.run(["wl-copy"], input=payload.encode("utf-8"), check=True)
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
