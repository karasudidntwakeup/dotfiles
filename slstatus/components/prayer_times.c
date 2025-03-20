// components/prayer_times.c

#include <stdio.h>
#include <string.h>
#include <time.h>
#include "../util.h"

#define MAX_PRAYER_LENGTH 20
#define MAX_OUTPUT_LENGTH 50

typedef struct {
    char name[MAX_PRAYER_LENGTH];
    int hour;
    int minute;
} PrayerTime;

int time_diff_minutes(int h1, int m1, int h2, int m2) {
    return (h2 * 60 + m2) - (h1 * 60 + m1);
}

const char *
prayer_times(const char *unused)
{
    static char output[MAX_OUTPUT_LENGTH];
    time_t t = time(NULL);
    struct tm *tm = localtime(&t);
    
    // Hardcoded prayer times for demonstration
    PrayerTime prayers[] = {
        {"Fajr", 4, 32},
        {"Dhuhr", 12, 02},
        {"Asr", 15, 30},
        {"Maghrib", 18, 06},
        {"Isha", 7, 24},
    };
    
    int num_prayers = sizeof(prayers) / sizeof(prayers[0]);
    int next_prayer_index = 0;
    
    // Find the next prayer
    for (int i = 0; i < num_prayers; i++) {
        if (tm->tm_hour < prayers[i].hour || 
            (tm->tm_hour == prayers[i].hour && tm->tm_min < prayers[i].minute)) {
            next_prayer_index = i;
            break;
        }
    }
    
    PrayerTime *next_prayer = &prayers[next_prayer_index];
    
    // Calculate time difference
    int diff_minutes = time_diff_minutes(tm->tm_hour, tm->tm_min, next_prayer->hour, next_prayer->minute);
    if (diff_minutes < 0) {
        diff_minutes += 24 * 60;  // Add a day if next prayer is tomorrow
    }
    
    int hours_left = diff_minutes / 60;
    int minutes_left = diff_minutes % 60;
    
    snprintf(output, MAX_OUTPUT_LENGTH, "%s in %d h %d m", next_prayer->name, hours_left, minutes_left);
    
    return output;
}
