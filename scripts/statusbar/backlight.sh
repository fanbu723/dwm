#!/bin/sh
# dwmblocks 模块：屏幕亮度
# 依赖：brightnessctl（推荐）→ xbacklight → /sys/class/backlight
#
# 注意：blocks.h 中该模块 interval = 0，只在收到信号时刷新。
#       调整亮度后需要：pkill -RTMIN+11 dwmblocks
#       （config.h 中的亮度快捷键已自动附带该命令）

if command -v brightnessctl >/dev/null 2>&1; then
	# -m 输出：device,class,current,percent%,max
	pct=$(brightnessctl -m 2>/dev/null | head -n1 | cut -d, -f4)
	if [ -n "$pct" ]; then
		printf '%s\n' "$pct"
		exit 0
	fi
fi

if command -v xbacklight >/dev/null 2>&1; then
	pct=$(xbacklight -get 2>/dev/null | awk '{ printf "%.0f%%", $1 }')
	if [ -n "$pct" ]; then
		printf '%s\n' "$pct"
		exit 0
	fi
fi

for bl in /sys/class/backlight/*; do
	[ -r "$bl/brightness" ] || continue
	cur=$(cat "$bl/brightness")
	max=$(cat "$bl/max_brightness" 2>/dev/null)
	[ "${max:-0}" -gt 0 ] || continue
	awk -v c="$cur" -v m="$max" 'BEGIN { printf "%.0f%%\n", 100 * c / m }'
	exit 0
done

printf '%s\n' "—"
