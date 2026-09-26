#!/bin/sh
# Weekly forecast backend (Open-Meteo, no API key).
# Output: two JSON lines — [{day,max,min,key}...] for 7 days, then
# {"hours":[{t,temp,key,day}...]} with the next 12 hours from now.
# Location: WX_LAT/WX_LON env override, else IP geolocation, else Cairo.
export WX_LAT="${WX_LAT:-}" WX_LON="${WX_LON:-}"
python3 - <<'EOF' || exit 1
import json, os, urllib.request
from datetime import datetime

def get(url, timeout):
    req = urllib.request.Request(url, headers={"User-Agent": "quickshell-weather/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)

lat, lon = os.environ.get("WX_LAT"), os.environ.get("WX_LON")
if not lat or not lon:
    try:
        geo = get("http://ip-api.com/json/?fields=status,lat,lon", 10)
        lat, lon = geo.get("lat"), geo.get("lon")
    except Exception:
        lat, lon = None, None
if not lat or not lon:
    lat, lon = 30.0444, 31.2357

def key_of(code):
    if code == 0:
        return "sun"
    if code in (1, 2):
        return "partly"
    if code == 3:
        return "cloud"
    if code in (45, 48):
        return "fog"
    if code in (71, 73, 75, 77, 85, 86):
        return "snow"
    if code in (95, 96, 99):
        return "storm"
    return "rain"

url = (f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}"
       "&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=7"
       "&hourly=temperature_2m,weather_code,is_day&forecast_days=7")
data = get(url, 15)
d = data.get("daily") or {}
times = d.get("time") or []
codes = d.get("weather_code") or []
maxs = d.get("temperature_2m_max") or []
mins = d.get("temperature_2m_min") or []
out = []
for i in range(min(7, len(times))):
    try:
        day = datetime.strptime(times[i], "%Y-%m-%d").strftime("%a")
    except Exception:
        day = times[i]
    out.append({
        "day": "Today" if i == 0 else day,
        "max": round(float(maxs[i])) if i < len(maxs) and maxs[i] is not None else 0,
        "min": round(float(mins[i])) if i < len(mins) and mins[i] is not None else 0,
        "key": key_of(int(codes[i])) if i < len(codes) and codes[i] is not None else "cloud",
    })
print(json.dumps(out))

h = data.get("hourly") or {}
ht, htemp, hcode, hday = h.get("time") or [], h.get("temperature_2m") or [], \
    h.get("weather_code") or [], h.get("is_day") or []
now = datetime.now().replace(minute=0, second=0, microsecond=0)
hours = []
for i in range(len(ht)):
    try:
        dt = datetime.strptime(ht[i], "%Y-%m-%dT%H:%M")
    except Exception:
        continue
    if dt < now:
        continue
    if len(hours) >= 12:
        break
    hours.append({
        "t": dt.strftime("%H"),
        "temp": round(float(htemp[i])) if i < len(htemp) and htemp[i] is not None else 0,
        "key": key_of(int(hcode[i])) if i < len(hcode) and hcode[i] is not None else "cloud",
        "day": bool(hday[i]) if i < len(hday) else True,
    })
print(json.dumps({"hours": hours}))
EOF
