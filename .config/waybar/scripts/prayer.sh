#!/usr/bin/env python3
import requests
from datetime import datetime

LAT = 30.7865
LON = 31.0004
METHOD = 5

try:
    data = requests.get(
        f"https://api.aladhan.com/v1/timings?latitude={LAT}&longitude={LON}&method={METHOD}",
        timeout=5
    ).json()
except Exception:
    print("API error")
    exit(1)

if data.get("code") != 200:
    print("API error")
    exit(1)

timings = data["data"]["timings"]
prayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]

now = datetime.now()
now_minutes = now.hour * 60 + now.minute

def time_to_minutes(t):
    h, m = map(int, t.split(":"))
    return h*60 + m

# تحديد الصلاة الجاية
next_prayer = "Fajr"
for prayer in prayers:
    if time_to_minutes(timings[prayer]) > now_minutes:
        next_prayer = prayer
        break

# Output واحد مناسب Waybar
print(f"{next_prayer} {timings[next_prayer]}")

