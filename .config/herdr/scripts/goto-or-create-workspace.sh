#!/bin/sh
# goto-or-create workspace by number: focus if exists, else create
N="$1"
if [ -z "$N" ]; then exit 1; fi
WS_ID=$(herdr workspace list 2>/dev/null | python3 -c "
import json,sys
n=$N
try:
  data=json.load(sys.stdin)
  for w in data.get('result',{}).get('workspaces',[]):
    if w.get('number')==n:
      print(w.get('workspace_id'))
      break
except Exception:
  pass
")
if [ -n "$WS_ID" ]; then
  herdr workspace focus "$WS_ID" >/dev/null 2>&1
else
  herdr workspace create --focus >/dev/null 2>&1
fi
