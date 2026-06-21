audio_volume=$(amixer -M get Master |\
awk '/Mono.+/ {print $6=="[off]" ?\
$4" ": \
$4" "}' |\
tr -d [])

uptime_formatted=$(uptime | cut -d ',' -f1  | cut -d ' ' -f4,5)

date_formatted=$(date "+%a %F %H:%M")

linux_version=$(uname -r | cut -d '-' -f1)

battery_info=$(upower --show-info $(upower --enumerate |\
grep 'BAT') |\
egrep "state|percentage" |\
awk '{print $2}')

echo $uptime_formatted ↑ $linux_version '|' $audio_volume '|' $battery_info '|' $date_formatted
