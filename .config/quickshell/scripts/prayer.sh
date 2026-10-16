#!/bin/sh
# Prayer pill backend (quickshell-local, no waybar dependency).
# Output: "<Name>|<DD-MM-YYYY HH:MM>" for the next prayer (24h time),
# e.g. "Maghrib|20-09-2026 18:24".
# Times are in SYSTEM-LOCAL wall time (what quickshell `new Date()` parses),
# converted from the location timezone (PRAYER_TZ / IP timezone / Berlin).
# Location: PRAYER_LAT/PRAYER_LON env override, else IP geolocation, else Berlin.
# Data: Aladhan API (no API key needed).
# Defaults suit Germany: method 3 (Muslim World League),
# school 1 (Hanafi). Override via PRAYER_METHOD / PRAYER_SCHOOL.

METHOD="${PRAYER_METHOD:-3}"
SCHOOL="${PRAYER_SCHOOL:-1}"
LAT="${PRAYER_LAT:-}"
LON="${PRAYER_LON:-}"
TZ_OVERRIDE="${PRAYER_TZ:-}"
if [ -z "$LAT" ] || [ -z "$LON" ]; then
    GEO=$(curl -s --max-time 10 "http://ip-api.com/json/?fields=status,lat,lon,timezone" 2>/dev/null || true)
    LAT=$(printf '%s' "$GEO" | jq -r '.lat // empty' 2>/dev/null)
    LON=$(printf '%s' "$GEO" | jq -r '.lon // empty' 2>/dev/null)
    GEO_TZ=$(printf '%s' "$GEO" | jq -r '.timezone // empty' 2>/dev/null)
fi
[ -n "$LAT" ] || LAT="52.5200"
[ -n "$LON" ] || LON="13.4050"
# Location timezone: explicit PRAYER_TZ wins, else IP timezone, else Berlin.
if [ -n "$TZ_OVERRIDE" ]; then
    GEO_TZ="$TZ_OVERRIDE"
else
    GEO_TZ="${GEO_TZ:-Europe/Berlin}"
fi

export P_LAT="$LAT" P_LON="$LON" P_TZ="$GEO_TZ" P_METHOD="$METHOD" P_SCHOOL="$SCHOOL"
python3 - <<'EOF' || exit 1
import datetime, json, os, urllib.request

LAT, LON = os.environ["P_LAT"], os.environ["P_LON"]
METHOD, SCHOOL = os.environ["P_METHOD"], os.environ["P_SCHOOL"]
try:
    from zoneinfo import ZoneInfo
    LOC_TZ = ZoneInfo(os.environ.get("P_TZ") or "Europe/Berlin")
except Exception:
    LOC_TZ = None
# System local tz (what quickshell `new Date(...)` parses as).
try:
    SYS_TZ = datetime.datetime.now().astimezone().tzinfo
except Exception:
    SYS_TZ = None

def fetch(date_str):
    url = (f"https://api.aladhan.com/v1/timings/{date_str}"
           f"?latitude={LAT}&longitude={LON}&method={METHOD}&school={SCHOOL}")
    req = urllib.request.Request(url, headers={"User-Agent": "quickshell-prayer/1.0"})
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.load(r)["data"]

def emit(name, target_loc):
    # Convert location-aware target to system-local wall time for QML.
    try:
        target_sys = target_loc.astimezone(SYS_TZ) if (SYS_TZ and target_loc.tzinfo) else target_loc
    except Exception:
        target_sys = target_loc
    print(f"{name}|{target_sys.day:02d}-{target_sys.month:02d}-{target_sys.year} "
          f"{target_sys.hour:02d}:{target_sys.minute:02d}")

ORDER = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
now_loc = datetime.datetime.now(LOC_TZ) if LOC_TZ else datetime.datetime.now()

data = fetch(now_loc.strftime("%d-%m-%Y"))
times = {k: data["timings"][k][:5] for k in ORDER}
for name in ORDER:
    h, m = map(int, times[name].split(":"))
    target = now_loc.replace(hour=h, minute=m, second=0, microsecond=0)
    if target > now_loc:
        emit(name, target)
        raise SystemExit(0)

# All today's prayers passed -> tomorrow's Fajr.
tomorrow_loc = now_loc + datetime.timedelta(days=1)
data2 = fetch(tomorrow_loc.strftime("%d-%m-%Y"))
h, m = map(int, data2["timings"]["Fajr"][:5].split(":"))
target2 = tomorrow_loc.replace(hour=h, minute=m, second=0, microsecond=0)
emit("Fajr", target2)
EOF
