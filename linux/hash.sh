#!/bin/bash

# Function to hash a single file and output "hash path"
do_hash() {
    sha256sum "$1" | awk '{printf "%s %s\n", $1, $2}'
}

while IFS= read -r path; do
    # Expand directories to file lists, or just use the file path
    targets=$( [ -d "$path" ] && find "$path" -type f | sort || echo "$path" )

    for file in $targets; do
        current_entry=$(do_hash "$file")
        
        if [ "$1" == "hash" ]; then
            echo "$current_entry" >> hashes
        elif [ "$1" == "check" ]; then
            grep -qF "$current_entry" hashes || echo "MISMATCH OR CHANGED: $file"
        fi
    done
done < to_check

# Reverse check: Find files in the 'hashes' file that no longer exist on disk
if [ "$1" == "check" ]; then
    while read -r line; do
        stored_path=$(echo "$line" | awk '{print $2}')
        if [ ! -e "$stored_path" ]; then
            echo "MISSING FILE (Stored in hashes but not on disk): $stored_path"
        fi
    done < hashes
fi