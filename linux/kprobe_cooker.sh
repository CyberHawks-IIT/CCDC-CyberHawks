#!/bin/bash

echo "==KPROBE COOKER=="

echo "Is kprobing enabled:"
sudo cat /sys/kernel/debug/kprobes/enabled

echo ""
echo "Registered kprobes (k for kprobe, j for jprobe, and r for return probe) (/sys/kernel/debug/kprobes/list):"
sudo cat /sys/kernel/debug/kprobes/list

echo ""
echo "Kprobes events (/sys/kernel/tracing/kprobe_events)":
sudo cat /sys/kernel/tracing/kprobe_events

echo ""
echo "Dynamic kprobe events (via ftrace) (/sys/kernel/debug/tracing/kprobe_events):"
sudo cat /sys/kernel/debug/tracing/kprobe_events

echo ""
echo "Dynamic kprobe events (via perf. if any found, delete with sudo perf probe -d '*' or sudo perf probe -d <name>):"
sudo perf probe -l

echo ""
echo "The ones that are active:"
sudo rg '1' /sys/kernel/debug/tracing/events/kprobes/*/enable

echo ""
echo "Turning off kprobes if it isn't already..."
sudo echo "0" > /sys/kernel/debug/kprobes/enabled