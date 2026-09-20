#!/bin/sh
# Prayer pill backend (quickshell-local, no waybar dependency).
# Output: "<Name>|<DD-MM-YYYY HH:MM>" for the next prayer (24h time),
# e.g. "Maghrib|20-09-2026 18:24".
# Location: PRAYER_LAT/PRAYER_LON env override, else IP geolocation, else Cairo.
# Data: Aladhan API (no API key needed).
# Defaults suit Egypt: method 5 (Egyptian General Authority of Survey),
# school 0 (Standard). Override via PRAYER_METHOD / PRAYER_SCHOOL.

METHOD="${PRAYER_METHOD:-5}"
SCHOOL="${PRAYER_SCHOOL:-0}"
LAT="${PRAYER_LAT:-}"
LON="${PRAYER_LON:-}"
if [ -z "$LAT" ] || [ -z "$LON" ]; then
    GEO=$(curl -s --max-time 10 "http://ip-api.com/json/?fields=status,lat,lon,timezone" 2>/dev/null || true)
    LAT=$(printf '%s' "$GEO" | jq -r '.lat // empty' 2>/dev/null)
    LON=$(printf '%s' "$GEO" | jq -r '.lon // empty' 2>/dev/null)
    GEO_TZ=$(printf '%s' "$GEO" | jq -r '.timezone // empty' 2>/dev/null)
fi
[ -n "$LAT" ] || LAT="30.0444"
[ -n "$LON" ] || LON="31.2357"
GEO_TZ="${GEO_TZ:-Africa/Cairo}"

export P_LAT="$LAT" P_LON="$LON" P_TZ="$GEO_TZ" P_METHOD="$METHOD" P_SCHOOL="$SCHOOL"
python3 - <<'EOF' || exit 1
import datetime, json, os, urllib.request

LAT, LON = os.environ["P_LAT"], os.environ["P_LON"]
METHOD, SCHOOL = os.environ["P_METHOD"], os.environ["P_SCHOOL"]
try:
    from zoneinfo import ZoneInfo
    TZ = ZoneInfo(os.environ.get("P_TZ") or "Africa/Cairo")
except Exception:
    TZ = None

def fetch(date_str):
    url = (f"https://api.aladhan.com/v1/timings/{date_str}"
           f"?latitude={LAT}&longitude={LON}&method={METHOD}&school={SCHOOL}")
    req = urllib.request.Request(url, headers={"User-Agent": "quickshell-prayer/1.0"})
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.load(r)["data"]

ORDER = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
now = datetime.datetime.now(TZ) if TZ else datetime.datetime.now()

data = fetch(now.strftime("%d-%m-%Y"))
times = {k: data["timings"][k][:5] for k in ORDER}
for name in ORDER:
    h, m = map(int, times[name].split(":"))
    target = now.replace(hour=h, minute=m, second=0, microsecond=0)
    if target > now:
        g = data["date"]["gregorian"]
        d, mo, y = int(g["day"]), int(g["month"]["number"]), int(g["year"])
        print(f"{name}|{d:02d}-{mo:02d}-{y} {times[name]}")
        raise SystemExit(0)

# All today's prayers passed -> tomorrow's Fajr.
tomorrow = now + datetime.timedelta(days=1)
data2 = fetch(tomorrow.strftime("%d-%m-%Y"))
g = data2["date"]["gregorian"]
d, mo, y = int(g["day"]), int(g["month"]["number"]), int(g["year"])
fajr = data2["timings"]["Fajr"][:5]
print(f"Fajr|{d:02d}-{mo:02d}-{y} {fajr}")
EOF
