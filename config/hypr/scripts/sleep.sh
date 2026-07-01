#!/usr/bin/env bash
swayidle -w timeout 600 'hyprlock' \
	# timeout 1200 'hyprctl dispatch dpms off' \
	# timeout 3600 'systemctl suspend' \
	resume 'hyprctl dispatch dpms on' \
	before-sleep 'hyprlock'
