#!/usr/bin/env bash
# Pick a file (photo/document) via zenity and send it with wacli.
set -euo pipefail
JID="$1"
command -v wacli >/dev/null 2>&1 || export PATH="$PATH:$HOME/go/bin"

FILE="$(zenity --file-selection --title='Send photo / file' \
    --file-filter='Images (*.png *.jpg *.jpeg *.webp *.gif *.jfif)' \
    --file-filter='All files (*.*)' 2>/dev/null)" || exit 1

exec wacli send file --to "$JID" --file "$FILE"