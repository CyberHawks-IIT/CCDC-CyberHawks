#!/bin/bash
echo "Finding elfs..."
sudo find / -type f -perm /a+x 2>/dev/null | while read -r file; do 
    if $(file "$file" | cut -d' ' -f2- | grep -Eq 'ELF '); then
        echo "$file" 
    fi
done > elfs
# sudo find / -path "/mnt" -prune -o -type f -perm /a+x 2>/dev/null | while read -r file; do if $(file "$file" | cut -d' ' -f2- | grep -Eq 'ELF '); then echo "$file"; fi done > elfs
echo "Finding tracked..."
sudo cat /var/lib/dpkg/info/*.md5sums | cut -d' ' -f2- | sort | uniq | while read -r line; do echo "/$line"; done > trk
echo "Comparing lists..."
sudo python3 trk.py
echo "NOT TRACKED (stripped is slight red flag):"
sudo cat non_trk | grep "." | while read -r line; do
    if [ -z "$(sudo readelf -s "$line" | grep -q FUNC)" ]; then
        echo "$line -- stripped function names";
    else
        echo "$line -- not stripped";
    fi 
done