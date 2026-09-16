#!/bin/sh
# dwmblocks 模块：电量
# 依赖：无（读取 /sys/class/power_supply），读不到时回退 acpi
#
# 输出：充电中为 "78%+"，放电 / 满电为 "78%"；无电池则为 "—"

percent=0
count=0
charging=""

for bat in /sys/class/power_supply/BAT*; do
	[ -r "$bat/capacity" ] || continue
	percent=$((percent + $(cat "$bat/capacity")))
	count=$((count + 1))
	[ "$(cat "$bat/status" 2>/dev/null)" = "Charging" ] && charging=1
done

if [ "$count" -gt 0 ]; then
	printf '%s%%%s\n' "$((percent / count))" "${charging:++}"
	exit 0
fi

if command -v acpi >/dev/null 2>&1; then
	acpi -b 2>/dev/null | awk 'NR == 1 {
		if (match($0, /[0-9]+%/)) p = substr($0, RSTART, RLENGTH)
		if (p != "") printf "%s%s\n", p, (index($0, "Charging") ? "+" : "")
	}'
	exit 0
fi

printf '%s\n' "—"
