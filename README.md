# Server Performance Stats

A Bash project that displays CPU, RAM, disk, and process statistics for a Linux computer or server in the terminal. You do not need to start a separate web server: the script reports on the Linux environment where it runs.

## Features

- Total CPU usage percentage, measured over approximately one second.
- Total, used, free, and available RAM, plus a memory usage percentage.
- Space usage for mounted local filesystems and their combined totals.
- The top five processes by CPU usage and by memory usage.
- Optional statistics: uptime, OS version, load average, and login records.

## Folder structure

Project directory: `server-performance-stats/`

| File | Purpose |
|---|---|
| `server-stats.sh` | The main Bash script that collects statistics and displays them in the terminal |
| `README.md` | Documentation covering setup, usage, code, and concepts |
| `.gitignore` | Lists temporary files and other files Git should not track; it can initially be empty |

## Requirements and limitations

Requires Bash, a mounted `/proc` filesystem, awk, GNU coreutils (`df`, `head`, `cat`, `sleep`, `nproc`), and procps (`free`, `ps`, `uptime`). It is intended for conventional Linux environments such as Ubuntu. Options may differ on BusyBox or minimal distributions, so compatibility with every Linux server has not been verified. This script is not intended for macOS. Reading the basic statistics does not require root access.

## Initial setup

```bash
mkdir server-performance-stats
cd server-performance-stats
touch server-stats.sh README.md .gitignore
chmod +x server-stats.sh
```

- `mkdir`: creates the directory.
- `cd`: enters the directory.
- `touch`: creates missing files as empty files; it does not erase an existing file's contents.
- `chmod +x`: adds execute permission; it does not run the script.

`chmod` changes file permissions, and `x` represents execute permission. Because `+x` does not specify a user class, the affected classes can be influenced by the umask. Use `chmod u+x server-stats.sh` to add the execute bit for the owner only; this does not remove permissions other users already have.

Execute permission does not grant root or administrator privileges. The script runs with the privileges of the user who launches it. Run only scripts you trust. A readable script without the execute bit can still be run with `bash server-stats.sh`, so the execute bit is not a complete security barrier.

```bash
nano server-stats.sh
```

In Nano, save with `Ctrl+O`, then `Enter`; exit with `Ctrl+X`.

```bash
bash -n server-stats.sh
./server-stats.sh
```

`bash -n` checks syntax only. A successful check with no output does not confirm that runtime calculations are correct. `./` refers to the current directory.

## Complete script

Place the following code in `server-stats.sh`. It combines the sections developed during the project and uses the C locale to make output parsing consistent.

```bash
#!/bin/bash
export LC_ALL=C

echo "Server Performance Stats"
echo
echo "Memory Usage"
free -h

echo
free -m | awk '/^Mem:/ {
    total = $2
    available = $7
    used = total - available
    if (total > 0)
        printf "Memory Usage: %.1f%%\n", (used / total) * 100
    else
        print "Memory Usage: N/A"
}'

echo
echo "Total Local Disk Usage"
df -h -l --total -x tmpfs -x devtmpfs -x efivarfs
echo
df -l -B1 --total -x tmpfs -x devtmpfs -x efivarfs |
    awk '$1 == "total" { printf "Disk Usage: %s\n", $5 }'

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
        printf "OS: %s\n" "${PRETTY_NAME:-Unknown Linux}"
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
printf "Available CPU processing units: "
nproc

echo
echo "--- Logged-in User Sessions ---"
who
```

## Bash basics

`#!/bin/bash` is the shebang that selects the Bash interpreter when the script is executed directly. `echo` displays text; an empty `echo` prints a blank line. The pipe operator, `|`, passes the previous command's standard output to the next command's input.

`awk` is a text-processing command that can select lines and fields, perform calculations, and format output. By default, it separates fields using whitespace.

```bash
free -m | awk '/^Mem:/ { print $2 }'
```

`/^Mem:/` selects the line beginning with `Mem:`. On that line, `$1` is the `Mem:` label, `$2` is total memory, `$3` is used memory, and `$7` is available memory. `print $2` displays the second field.

In formatted output, `%s` represents a string, `%.1f` represents a number with one decimal place, `%%` prints a literal percent sign, and `\n` starts a new line.

## Memory and units

`free -h` displays human-readable units; `free -m` reports values in MiB.

| Column | Meaning |
|---|---|
| total | Total RAM usable by the system |
| used | Used RAM as reported by the installed version of free |
| free | Unused RAM |
| shared | Primarily shared memory |
| buff/cache | Buffers and cache |
| available | Estimated RAM available for new work without swapping |

Some cached memory can be reclaimed when needed, so a low free value does not necessarily mean the system has run out of RAM. Swap is disk-backed storage that supports memory management. Swap usage alone does not prove that the system is currently under memory pressure.

| Abbreviation | Name | Size |
|---|---|---|
| Ki | KiB, kibibyte | 1,024 bytes |
| Mi | MiB, mebibyte | 1,024 KiB |
| Gi | GiB, gibibyte | 1,024 MiB |

Decimal KB/MB/GB units use multiples of 1,000. One GiB is approximately 1.074 GB.

The script uses `used = total - available`, then calculates the percentage as `used / total * 100`. Depending on the version of `free`, its displayed used column may use a different definition. The script also calls `free` twice, so there is a small time difference between the readings.

## Disk commands and awk

The initial version displayed only the root filesystem:

```bash
df -h /
df -h / | awk 'NR==2 { printf "Disk Usage: %s\n", $5 }'
```

`df` reports filesystem space usage. `-h` selects human-readable units, and `/` selects the root filesystem. `NR==2` selects the second output line, and `$5` selects the Use% column. Since that value already contains a percent sign, `%s` prints it as text. This extracts the percentage calculated by `df`; it does not calculate a new percentage. The final version replaces this root-only section with combined local filesystem statistics.

| Option | Meaning |
|---|---|
| `-l` | Include local filesystems only |
| `--total` | Add a total row |
| `-B1` | Report sizes in bytes |
| `-x tmpfs` | Exclude RAM-backed temporary filesystems, which may also use swap |
| `-x devtmpfs` | Exclude the kernel-managed filesystem for device nodes |
| `-x efivarfs` | Exclude the firmware variables filesystem |

`-x` means exclude. The awk condition `$1 == "total"` selects the total row. Only mounted local filesystems are included; unmounted partitions and unpartitioned space are not. Containers, overlay filesystems, and shared storage configurations can cause double counting, so review the filesystem list. This is not a measurement of the physical SSD's total capacity.

`Size`, `Used`, `Avail`, `Use%`, and `Mounted on` mean total space, used space, available space, usage percentage, and mount location. Reserved blocks and rounding can cause Used + Avail to differ from Size. GNU df generally bases Use% on used/(used+available), rounded up to the next integer.

### LC_ALL=C

`C` is the name of a standard locale, not an abbreviation for English. A locale controls language, decimal formatting, sorting, and related conventions. The C locale generally produces basic English messages and uses `.` as the decimal point. This helps the script reliably match words such as `total`.

```bash
LC_ALL=C df -h
```

Do not put spaces around `=`. The assignment above affects only that command. In the complete script, `export LC_ALL=C` applies to the script and its child commands. Running it as `./server-stats.sh` does not change the parent terminal's language settings.

## Top processes

```bash
ps -eo pid,comm,%cpu --sort=-%cpu | head -n 6
ps -eo pid,comm,%mem --sort=-%mem | head -n 6
```

`ps` reports process information. `-e` selects all processes, and `-o` selects the output columns. PID means process identifier; comm is the command name. `--sort=-%cpu` and `--sort=-%mem` sort from highest to lowest usage. `head -n 6` displays the heading plus five processes.

The CPU percentage reported by ps is an average over the process's lifetime. MEM% is the process's resident memory as a proportion of physical RAM. Shared pages mean that adding process memory percentages does not accurately reproduce total RAM usage. A process using multiple threads across multiple cores can exceed 100% CPU usage. Do not compare these values directly with the script's one-second, system-wide CPU sample.

## CPU usage: detailed explanation

CPU usage is the percentage of a time interval during which the CPU was busy. It is not a storage quantity like RAM. If one core works for 0.7 seconds and is idle for 0.3 seconds during a one-second interval, its usage is 70%.

`/proc/stat` provides cumulative CPU counters. These accumulate since system startup, so recent usage is calculated from the difference between two readings.

1. The first `cat /proc/stat` reads the initial counters.
2. `sleep 1` waits approximately one second.
3. The second `cat /proc/stat` reads the updated counters.
4. Their differences provide the busy-time percentage for that interval.

`<(...)` is Bash process substitution. It supplies the enclosed commands' output to awk as though it were a file. This is not POSIX sh syntax, so do not run the script with `sh server-stats.sh`.

`/^cpu /` matches the aggregate line beginning with `cpu` followed by a space. It does not select individual CPU lines such as `cpu0` and `cpu1`.

| Field | Counter |
|---|---|
| $1 | cpu label |
| $2 | user |
| $3 | nice |
| $4 | system/kernel |
| $5 | idle |
| $6 | iowait |
| $7 | hardware interrupts |
| $8 | software interrupts |
| $9 | steal |

`total = 0` resets the sum for each sample. `for (i = 2; i <= 9; i++)` iterates through fields 2–9. `$i` means the field whose number is i. `total += $i` is equivalent to `total = total + $i`. Guest and guest_nice counters are already included in user/nice, so they are not added again.

`idle = $5 + $6` treats idle and I/O wait as non-busy time for this calculation. I/O wait is associated with CPU idle time and pending I/O; it is not a precise per-task waiting-time measurement on multicore systems.

Because `sample` is initially uninitialized, it behaves as zero in the numeric comparison. Within `if (sample == 0)`, the first total and idle values are saved in the previous-value variables, and `sample` is set to 1. When the second aggregate line arrives, the else branch runs.

```awk
total_diff = total - previous_total
idle_diff = idle - previous_idle
usage = 100 * (total_diff - idle_diff) / total_diff
```

| Counter | First reading | Second reading | Difference |
|---|---:|---:|---:|
| total | 1000 | 1100 | 100 |
| idle + iowait | 600 | 630 | 30 |

Busy time = 100 - 30 = 70; usage = 70/100 × 100 = 70%.

`if (total_diff > 0)` prevents division by zero; otherwise, N/A is displayed. `printf "CPU Usage: %.1f%%\n", usage` prints one decimal place, a percent sign, and a newline.

Under normal conditions, aggregate usage is on a 0–100% scale. If one of four equivalent processing units is fully busy while the others are idle, the result is approximately 25%. This formula counts steal time on the busy side, so in a virtual machine it is not solely a measurement of time the guest actually executed. Rare conditions such as kernel iowait counter anomalies or resets are not specially handled.

## Optional statistics

### Uptime

`uptime -p` displays the time since the last boot in a readable format, such as `up 3 hours, 25 minutes`.

### OS information and if/fi

`/etc/os-release` contains variables describing the distribution's name and version. `[ -r /etc/os-release ]` checks whether the file is readable. `. /etc/os-release` loads its variables. PRETTY_NAME provides a readable OS name. The `( ... )` subshell keeps these variables from affecting other parts of the script.

```bash
if [ -r /etc/os-release ]; then
    echo "The file is readable"
else
    echo "The file is not readable"
fi
```

`if` checks the condition; `then` begins the true branch; `else` begins the false branch; and `fi` closes the if block. The word `if` written backward is `fi`. Every Bash if statement must end with fi. Awk uses different if syntax and braces; do not add fi to awk code.

### Load average and /proc/loadavg

`/proc/loadavg` is a virtual file supplied by the kernel, not a command.

```bash
cat /proc/loadavg
```

Entering only the path in the terminal makes the shell try to execute it, which can produce Permission denied. Use cat to read it; chmod +x is unnecessary.

Example output: `0.52 0.81 0.74 2/850 12345`.

| Value | Meaning |
|---|---|
| 0.52 | 1-minute load average |
| 0.81 | 5-minute load average |
| 0.74 | 15-minute load average |
| 2/850 | Runnable scheduling entities / total existing scheduling entities, including threads |
| 12345 | PID of the most recently created process |

Load average is a time-smoothed average based on runnable tasks and tasks in uninterruptible sleep, often associated with I/O. It is not a CPU percentage. `nproc` reports the processing units available to the process, which need not equal the number of physical cores.

For a system with four processing units doing CPU-only work, a load of 4 roughly represents full capacity, while a load of 8 may indicate queued work. I/O waits can also increase load, so these are not universal thresholds. Consider differences between container CPU limits and host-wide load as well.

In practice, load average helps identify increasing demand, sustained load, and recovery on a slow server. A 1-minute value higher than the 5- and 15-minute values suggests a recent increase. High load does not predict a crash by itself. Assess it alongside CPU, RAM, I/O, latency, and errors. Scaling may help a sustained CPU bottleneck, but adding CPU capacity may not solve a disk bottleneck. This script generates a one-time report; it does not implement alerts or autoscaling.

### Logged-in sessions

`who` displays login accounting records, including the username, terminal, login time, and sometimes a source or label. The number of rows is not the number of unique users. Some desktop or container environments may have no records.

During this project, who displayed two rows for the same user: `seat0 (login screen)` and `tty2 (tty2)`. This alone does not establish that there are separate CLI and GUI sessions, or that two desktop workspaces caused the output.

```bash
loginctl list-sessions
loginctl show-session 2 -p Type -p Class
```

The check showed only session 2, active on seat0/tty2. `Type=wayland` and `Class=user` confirmed a regular graphical user session. `seat0` identifies the local device seat, and tty2 identifies the virtual terminal. Workspaces can belong to the same desktop session. The exact component that wrote the two who records was not identified. On another system, use the session ID returned by list-sessions rather than assuming it is 2.

## Verification and final status

Screenshots from the user's Linux laptop showed working CPU, memory, local disk totals, and top-five process lists. The user reported successful uptime and OS information steps. Terminal output also confirmed the session type. This does not constitute exhaustive testing across all Linux distributions.

After copying the final code, run:

```bash
bash -n server-stats.sh
./server-stats.sh
```

Check that all headings appear and the values are plausible. CPU sampling takes approximately one second. Statistics change over time, so the values do not need to match earlier screenshots. Sudo is not required. The optional failed-login-attempts feature is not included in this version; relevant logs and permissions vary by distribution.

https://roadmap.sh/projects/server-stats

## References

- [GNU coreutils manual](https://www.gnu.org/software/coreutils/manual/coreutils.html)
- [Linux proc_stat manual](https://man7.org/linux/man-pages/man5/proc_stat.5.html)
- [Linux proc_loadavg manual](https://man7.org/linux/man-pages/man5/proc_loadavg.5.html)
- [systemd session properties](https://www.freedesktop.org/software/systemd/man/262/org.freedesktop.login1.html)
- [loginctl documentation](https://freedesktop.org/software/systemd/man/devel/loginctl.html)
