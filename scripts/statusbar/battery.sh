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
	pct=$((percent / count))
	if [ -n "$charging" ]; then
		printf '^c#7dcfff^%s%%+^d^\n' "$pct"	# 充电中：青色 + 加号
	elif [ "$pct" -le 10 ]; then
		printf '^c#f7768e^%s%%^d^\n' "$pct"	# 快没电：红
	elif [ "$pct" -le 20 ]; then
		printf '^c#e0af68^%s%%^d^\n' "$pct"	# 偏少：琥珀
	else
		printf '%s%%\n' "$pct"
	fi
	exit 0
fi

if command -v acpi >/dev/null 2>&1; then
	acpi -b 2>/dev/null | awk 'NR == 1 {
		if (match($0, /[0-9]+%/)) p = substr($0, RSTART, RLENGTH)
		if (p == "") exit
		sub(/%/, "", p)
		if (index($0, "Charging")) printf "^c#7dcfff^%s%%+^d^\n", p
		else if (p + 0 <= 10)      printf "^c#f7768e^%s%%^d^\n", p
		else if (p + 0 <= 20)      printf "^c#e0af68^%s%%^d^\n", p
		else                       printf "%s%%\n", p
	}'
	exit 0
fi

printf '%s\n' "—"
