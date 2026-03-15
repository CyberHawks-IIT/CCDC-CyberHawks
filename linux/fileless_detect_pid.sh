#!/bin/bash
echol () {
    echo "";
    echo "$@";
}

annotate_pid() {
    while IFS= read -r line; do
        pid=$(echo "$line" | grep -oP '/proc/\K\d+')
        if [[ -n "$pid" ]]; then
            comm=$(cat /proc/$pid/comm 2>/dev/null || echo "unknown")
            echo "[$pid:$comm] $line"
        else
            echo "$line"
        fi
    done
}

is_actually_deleted() {
    local path="$1"
    local clean_path="${path% (deleted)}"
    if [[ -e "$clean_path" ]]; then
        return 1
    fi
    return 0
}

echo "FILELESS MALWARE DETECTOR"
echo "---------------------------"

echol "Search for deleted files running as a process:"
while IFS= read -r line; do
    link_target=$(echo "$line" | grep -oP '/proc/\d+/exe -> \K.*' | sed 's/ (deleted)//')
    if [[ -z "$link_target" ]]; then
        echo "$line" | annotate_pid
        continue
    fi
    if is_actually_deleted "$link_target"; then
        echo "$line" | annotate_pid
    fi
done < <(sudo rg --pre $PWD/lah.sh "deleted" /proc/*/exe 2>/dev/null)

echol "Search for processes that are running off a file created in the RAM using memfd_create syscall:"
sudo rg --pre $PWD/lah.sh "memfd" /proc/*/exe 2>/dev/null | annotate_pid

echol "Search for files that are in RAM directories (/dev/shm or /run/shm):"
sudo rg --pre $PWD/lah.sh "/dev/shm|/run/shm" /proc/*/exe 2>/dev/null | annotate_pid
sudo rg --pre strings "/dev/shm|/run/shm" /proc/*/cmdline 2>/dev/null | annotate_pid

echol "Search for open files marked as deleted:"
while IFS= read -r line; do
    file_path=$(echo "$line" | awk '{print $NF}' | sed 's/ (deleted)//')
    if is_actually_deleted "$file_path"; then
        echo "$line"
    fi
done < <(sudo lsof | rg "(deleted)")

echol "Search for open files in RAM created with memfd:"
sudo lsof | rg "/memfd"

echol "Search for processes with rwx regions in memory:"
sudo rg "rwxp" /proc/*/maps 2>/dev/null | annotate_pid
