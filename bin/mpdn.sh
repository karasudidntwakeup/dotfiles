#!/bin/bash

# Function to send a notification
send_notification() {
    local song="$1"
    local id="$2"
    notify-send -r "$id" "Now Playing" "$song"
}

# Initialize a variable to store the current song
current_song=""
# Initialize a variable to store the notification ID
notify_id=12345  # You can choose any unique number

while true; do
    # Retrieve the currently playing song
    new_song=$(mpc current --wait)

    # Check if the song has changed
    if [ "$new_song" != "$current_song" ]; then
        # Update the current song variable
        current_song="$new_song"

        # Send a notification with the specified ID
        send_notification "$current_song" "$notify_id"
    fi

    # Wait for a short period before checking again
    sleep 1
done

