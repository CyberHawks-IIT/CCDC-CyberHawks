#!/bin/bash

for var in "$@"
do
	systemctl stop "$var"
	systemctl disable "$var"
	systemctl mask "$var"
	file = $(systemctl show -P FragmentPath "$var")
	if [ -n "$file" ]; then
		mv "$file" "$file.bak"
		echo "$file" >> killed_services
	else
		echo "$var" >> killed_services
	fi
done
systemctl daemon-reload