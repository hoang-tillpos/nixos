swayidle -w timeout 300 'hyprlock' \
	timeout 600 'hyprctl dispatch dpms off' \
	resume 'hyprctl dispatch dpms on' \
	before-sleep 'hyprlock' #timeout 900 'systemctl suspend' \
