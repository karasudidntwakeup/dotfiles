"""Apply the generated Foot palette to new and running terminals."""

import configparser
import os
from pathlib import Path
import re
import sys


def foot_ptys():
    """Find PTY slaves whose master is held by a Foot process."""
    for process in Path("/proc").glob("[0-9]*"):
        try:
            if process.stat().st_uid != os.getuid():
                continue
            if (process / "comm").read_text().strip() != "foot":
                continue
            descriptors = list((process / "fdinfo").iterdir())
        except OSError:
            continue

        for descriptor in descriptors:
            try:
                info = descriptor.read_text()
            except OSError:
                continue
            match = re.search(r"^tty-index:\s*([0-9]+)$", info, re.MULTILINE)
            if match:
                yield Path("/dev/pts") / match[1]


def palette_bytes(palette):
    def color(key, last=False):
        value = palette.get(key, "").split()
        hex_value = value[-1 if last else 0] if value else ""
        return "#" + hex_value if re.fullmatch(r"[0-9a-fA-F]{6}", hex_value) else ""

    sequences = []
    for offset, group in ((0, "regular"), (8, "bright")):
        for index in range(8):
            rgb = color(f"{group}{index}")
            if rgb:
                sequences.append(f"4;{offset + index};{rgb}")

    for code, key in ((10, "foreground"), (11, "background"), (12, "cursor"),
                      (17, "selection-background"), (19, "selection-foreground")):
        rgb = color(key, last=key == "cursor")
        if rgb:
            sequences.append(f"{code};{rgb}")

    return "".join(f"\x1b]{sequence}\x1b\\" for sequence in sequences).encode("ascii")


def apply(mode):
    config_dir = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    path = config_dir / "foot" / "foot.ini"
    if not path.is_file():
        return

    text = path.read_text()
    config = configparser.ConfigParser(interpolation=None, strict=False)
    config.read_string(text)
    section = f"colors-{mode}"
    if section not in config:
        return

    # Preserve the generated file's comments, formatting, and other options.
    main = re.search(
        r"^\[main\][^\n]*\n(.*?)(?=^[ \t]*\[|\Z)", text, re.MULTILINE | re.DOTALL
    )
    if main:
        setting = f"initial-color-theme={mode}"
        body, count = re.subn(r"^[ \t]*initial-color-theme[ \t]*=.*$", setting, main[1], flags=re.MULTILINE)
        if not count:
            body = setting + "\n" + body
        updated = text[:main.start(1)] + body + text[main.end(1):]
        if updated != text:
            path.write_text(updated)

    sequences = palette_bytes(config[section])
    for tty in set(foot_ptys()):
        try:
            fd = os.open(tty, os.O_WRONLY | os.O_NOCTTY | os.O_NONBLOCK)
            try:
                os.write(fd, sequences)
            finally:
                os.close(fd)
        except OSError:
            continue


if __name__ == "__main__":
    try:
        apply(sys.argv[1])
    except (OSError, configparser.Error) as error:
        print(f"Foot colors: {error}", file=sys.stderr)
