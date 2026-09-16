#!/bin/sh
# dwmblocks 模块：CPU 使用率
# 依赖：awk（读取 /proc/stat）
#
# 说明：与上次采样求差得到使用率，脚本自身不 sleep，
#       因此不会像「读一次 → sleep 5 秒 → 再读一次」那样阻塞整个状态栏。

cache="${XDG_RUNTIME_DIR:-/tmp}/dwmblocks-cpu-$(id -u).cache"

# $4 = idle，$2..$8 = user+nice+system+idle+iowait+irq+softirq
line=$(awk '/^cpu / { print $4, $2+$3+$4+$5+$6+$7+$8; exit }' /proc/stat)
if [ -z "$line" ]; then
	printf '%s\n' "—"
	exit 0
fi
idle=${line% *}
total=${line#* }

old_idle=""
old_total=""
if [ -r "$cache" ]; then
	read -r old_idle old_total <"$cache" 2>/dev/null || true
fi

printf '%s %s\n' "$idle" "$total" >"$cache"

if [ -z "$old_total" ]; then
	printf '%s\n' "—"
	exit 0
fi

awk -v di="$((idle - old_idle))" -v dt="$((total - old_total))" 'BEGIN {
	if (dt <= 0) { print "—"; exit }
	printf "%.0f%%\n", 100 * (1 - di / dt)
}'
