// Get current date/time in Egypt timezone (Africa/Cairo)
const now = new Date().toLocaleString('en-US', {
  timeZone: 'Africa/Cairo',
  hour12: false
});
const currentTime = new Date(now);

async function getNextPrayer() {
  try {
    // Fetch prayer times from Islamic Finder API
    const response = await fetch(
      'https://api.islamicfinder.org/api/prayer_times?city=Cairo&country=Egypt'
    );
    const data = await response.json();
    
    // Extract prayer times (example format from [[2]])
    const prayerTimes = {
      Fajr: data.fajr,
      Dhuhr: data.dhuhr,
      Asr: data.asr,
      Maghrib: data.maghrib,
      Isha: data.isha
    };

    // Convert prayer times to Date objects
    const today = new Date().toLocaleDateString('en-US', { timeZone: 'Africa/Cairo' });
    const prayerDates = Object.entries(prayerTimes).map(([name, time]) => {
      const [hours, minutes] = time.split(/[: ]/);
      return {
        name,
        time: new Date(`${today} ${hours}:${minutes}:00`)
      };
    });

    // Find next prayer time
    let nextPrayer = null;
    for (const prayer of prayerDates) {
      if (prayer.time > currentTime) {
        nextPrayer = prayer;
        break;
      }
    }

    // If all prayers have passed, get tomorrow's Fajr
    if (!nextPrayer) {
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      const tomorrowDate = tomorrow.toLocaleDateString('en-US', { timeZone: 'Africa/Cairo' });
      nextPrayer = {
        name: 'Fajr (Tomorrow)',
        time: new Date(`${tomorrowDate} ${prayerTimes.Fajr}:00`)
      };
    }

    // Calculate time difference
    const diff = nextPrayer.time - currentTime;
    const hours = Math.floor(diff / 3600000);
    const minutes = Math.floor((diff % 3600000) / 60000);

    return `Next prayer (${nextPrayer.name}) in: ${hours}h ${minutes}m`;

  } catch (error) {
    return 'Error fetching prayer times. Check your connection.';
  }
}

// Example usage
getNextPrayer().then(console.log);
