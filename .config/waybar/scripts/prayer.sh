#!/usr/bin/env python3
import requests
from datetime import datetime

LAT = 30.0444
LON = 31.2357
METHOD = 5

URL = f"https://api.aladhan.com/v1/timings?latitude={LAT}&longitude={LON}&method={METHOD}"

try:
    resp = requests.get(URL, timeout=5)
    data = resp.json()
except Exception:
    print("  API error")
    exit(1)

if data.get("code") != 200:
    print("  API error")
    exit(1)

timings = data["data"]["timings"]
prayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]

now = datetime.now()
now_minutes = now.hour * 60 + now.minute

def time_to_minutes(t):
    h, m = map(int, t.split(":"))
    return h * 60 + m

for prayer in prayers:
    t = timings[prayer]
    if time_to_minutes(t) > now_minutes:
        print(f"  {prayer} {t}")
        exit(0)

print(f"  Fajr {timings['Fajr']}")

