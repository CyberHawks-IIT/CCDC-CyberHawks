#!/bin/bash

# Cook Ptrace
sudo ./ptrace_cooker.sh

# Check for FTRACE Hooking
echo ""
sudo ./ftrace_cooker.sh

# Cook kprobe
echo ""
sudo ./kprobe_cooker.sh