swayidle -w timeout 600 'hyprlock' \
	timeout 1200 'hyprctl dispatch dpms off' \
	resume 'hyprctl dispatch dpms on' \
	before-sleep 'hyprlock' #timeout 900 'systemctl suspend' \
