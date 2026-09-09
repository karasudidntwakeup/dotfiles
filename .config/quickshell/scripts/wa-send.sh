#!/usr/bin/env bash
# Send a WhatsApp text message to a chat JID.
JID="$1"
TEXT="$2"

command -v wacli >/dev/null 2>&1 || export PATH="$PATH:$HOME/go/bin"

wacli send text --to "$JID" --message "$TEXT" >/dev/null 2>&1