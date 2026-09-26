#!/bin/sh
# Weather pill backend (quickshell-local, no waybar dependency).
# Output: "<key>|<text>|<day|night>|<feels>|<city>"
#   key  = sun|partly|cloud|rain|storm|snow|fog
#   text = e.g. "30°C", feels = e.g. "29°C", city = e.g. "Cairo"
# Location: WX_LAT/WX_LON env override, else IP geolocation, else Cairo.
# Data: Open-Meteo (no API key needed).

export WX_LAT="${WX_LAT:-}" WX_LON="${WX_LON:-}"
python3 - <<'EOF' || exit 1
import json, os, urllib.request

def get(url, timeout):
    req = urllib.request.Request(url, headers={"User-Agent": "quickshell-weather/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)

lat, lon = os.environ.get("WX_LAT"), os.environ.get("WX_LON")
city = ""
if not lat or not lon:
    try:
        geo = get("http://ip-api.com/json/?fields=status,lat,lon,city", 10)
        lat, lon, city = geo.get("lat"), geo.get("lon"), geo.get("city") or ""
    except Exception:
        lat, lon = None, None
if not lat or not lon:
    lat, lon, city = 30.0444, 31.2357, "Cairo"  # Cairo fallback

url = (f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}"
       f"&current=temperature_2m,apparent_temperature,weather_code,is_day&timezone=auto")
data = get(url, 15)
c = data.get("current") or {}
t, code, day = c.get("temperature_2m"), c.get("weather_code"), c.get("is_day", 1)
fl = c.get("apparent_temperature")
if t is None or code is None:
    raise SystemExit(1)
code = int(code)
if code == 0:
    k = "sun"
elif code in (1, 2):
    k = "partly"
elif code == 3:
    k = "cloud"
elif code in (45, 48):
    k = "fog"
elif code in (71, 73, 75, 77, 85, 86):
    k = "snow"
elif code in (95, 96, 99):
    k = "storm"
else:
    k = "rain"  # drizzle / rain / freezing rain / showers
dn = "day" if day else "night"
feels = f"{round(float(fl))}\u00b0C" if fl is not None else ""
print(f"{k}|{round(float(t))}\u00b0C|{dn}|{feels}|{city}")
EOF
