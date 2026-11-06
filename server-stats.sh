#!/bin/bash

echo "Server Performance Stats"

echo 
echo "Memory Usage"
free -h

echo
free -m | awk '/^Mem:/ {
    total = $2
    available = $7
    used = total - available

    printf "Memory Usage: %.1f%%\n", (used / total) * 100
}'

echo
echo "Total Local Disk Usage"
df -h -l --total -x tmpfs -x devtmpfs -x efivarfs

echo
LC_ALL=C df -l -B1 --total -x tmpfs -x devtmpfs -x efivarfs |
    awk '$1 == "total" {
        printf "Disk Usage: %s\n", $5
    }'
echo

echo "Top 5 Processes by CPU Usage"
ps -eo pid,comm,%cpu --sort=-%cpu | head -n 6

echo
echo "Top 5 Processes by Memory Usage"
ps -eo pid,comm,%mem --sort=-%mem | head -n 6

echo
echo "Total CPU Usage"
awk '
    /^cpu / {
        total = 0
        for (i = 2; i <= 9; i++) {
            total += $i
        }
        idle = $5 + $6

        if (sample == 0) {
            previous_total = total
            previous_idle = idle
            sample = 1
        } else {
            total_diff = total - previous_total
            idle_diff = idle - previous_idle

            if (total_diff > 0) {
                usage = 100 * (total_diff - idle_diff) / total_diff
                printf "CPU Usage: %.1f%%\n", usage
            } else {
                print "CPU Usage: N/A"
            }
        }
    }
' <(cat /proc/stat; sleep 1; cat /proc/stat)


echo
echo "--- System Uptime ---"
uptime -p

echo
echo "--- Operating System ---"

if [ -r /etc/os-release ]; then
    (
        . /etc/os-release
        printf "OS: %s\n" "$PRETTY_NAME"
    )
else
    echo "OS information unavailable"
fi

echo
echo "--- Load Average ---"

awk '{
    printf "Last 1 minute: %s\n", $1
    printf "Last 5 minutes: %s\n", $2
    printf "Last 15 minutes: %s\n", $3
}' /proc/loadavg

printf "Available CPU cores: "
nproc

echo
echo "--- Logged-in User Sessions ---"
who

