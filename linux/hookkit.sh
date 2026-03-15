#!/bin/bash

# Cook Ptrace
sudo ./ptrace_cooker.sh

# Check for FTRACE Hooking
echo ""
sudo ./ftrace_cooker.sh

# Cook kprobe
echo ""
sudo ./kprobe_cooker.sh

# Cook ebpf
echo ""
sudo ./ebpf_cooker.sh