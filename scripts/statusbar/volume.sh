#!/bin/sh
# dwmblocks 模块：音量
# 依赖：pactl（pipewire-pulse / pulseaudio）或 amixer（alsa-utils）
#
# 注意：blocks.h 中该模块 interval = 0，只在收到信号时刷新。
#       调整音量后需要：pkill -RTMIN+11 dwmblocks
#       （config.h 中的音量快捷键已自动附带该命令）

vol=""

if command -v pactl >/dev/null 2>&1; then
	if [ "$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')" = "yes" ]; then
		printf '%s\n' "静音"
		exit 0
	fi
	vol=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | awk 'NR == 1 { print $5 }')
fi

if [ -z "$vol" ] && command -v amixer >/dev/null 2>&1; then
	# amixer 输出形如：Playback 65536 [100%] [on]
	vol=$(amixer get Master 2>/dev/null \
		| awk -F'[][]' '/\[[0-9]+%\]/ { v = $2; m = $4 } END { if (v != "") printf "%s%s\n", v, (m == "off" ? " (静音)" : "") }')
fi

if [ -z "$vol" ]; then
	printf '%s\n' "—"
else
	printf '%s\n' "$vol"
fi
