#!/bin/bash

function echol(){
    echo "";
    echo "$@";
}

echo "==EBPF COOKER=="
echo "List loaded eBPF programs:"
sudo bpftool prog list

echol "Network attachments:"
sudo bpftool net list

echol "Active links:"
sudo bpftool link list

echol "List all raw_tracepoint, tracepoint, kprobe attachments in the system:"
sudo bpftool perf list

echol "Show eBPF trace logs:"
sudo bpftool prog trace log

echol "Check if ip link has XDP programs:"
sudo ip link show | grep "prog/xdp"

echol "Checking mount for bpf:"
sudo mount | grep bpf

echol "Monitoring the BPF filesystem for pinned objects that attackers may use for persistence (bpffs):"
sudo ls -lah /sys/fs/bpf

echol "Check if any TC programs are loaded:"
sudo tc filter show

echol "Check dmesg for BPF-related warnings"
sudo dmesg | grep bpf
echo ""

# BPFDoor-like Suspicious Process Detector

# Check for root permission
if [ "$(id -u)" -ne 0 ]; then
  echo "[!] This script must be run as root."
  exit 1
fi

# Check required commands
for cmd in ps grep readlink ss; do
  if ! command -v $cmd &>/dev/null; then
    echo "[!] $cmd command is required. Please install it first."
    exit 1
  fi
done

echo "[*] Starting focused BPFDoor-like process detection..."

found=0

# Iterate over all PIDs
for pid in $(ls /proc/ | grep -E '^[0-9]+$'); do
  [ -d "/proc/$pid" ] || continue

  exe_path=$(readlink /proc/$pid/exe 2>/dev/null)

  if [[ $exe_path == *"(deleted)" ]]; then
    if [ -r /proc/$pid/net/packet ] && [ -s /proc/$pid/net/packet ]; then
      cmdline=$(ps -p $pid -o cmd= 2>/dev/null)

      if [[ ! $cmdline =~ "tcpdump|wireshark|dhclient" ]]; then
        echo "[!] Suspicious process detected:"
        echo "    - PID: $pid"
        echo "    - Command: $cmdline"
        echo "    - Deleted executable: $exe_path"
        echo "    - BPF socket is active"

        ss -p -n 2>/dev/null | grep "pid=$pid," | awk '{print "    - Network: " $0}'
        echo ""

        found=1
      fi
    fi
  fi

done

[ $found -eq 0 ] && echo "[*] No suspicious processes found."

echo "[*] Detection completed."

echol "Disabling Unprivileged BPF if not already:"
sudo sysctl kernel.unprivileged_bpf_disabled

echol "To unload program: sudo rm /sys/fs/bpf/flat"
echo "Detach the eBPF program from the NIC: sudo bpftool net detach xdp dev eth0"