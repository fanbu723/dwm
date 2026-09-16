#!/bin/sh
# dwmblocks 模块：实时网速（⬇ 下行 / ⬆ 上行）
# 依赖：iproute2、awk、date
#
# 说明：把上次采样缓存在 runtime 目录，本次与上次求差，
#       因此脚本自身不 sleep，不会阻塞 dwmblocks 的其他模块。

cache="${XDG_RUNTIME_DIR:-/tmp}/dwmblocks-wlan-$(id -u).cache"

iface=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')
if [ -z "$iface" ]; then
	printf '%s\n' "无网络"
	exit 0
fi

line=$(awk -v i="$iface" '$1 == i":" {print $2, $10; exit}' /proc/net/dev)
if [ -z "$line" ]; then
	printf '%s\n' "—"
	exit 0
fi
rx=${line% *}
tx=${line#* }

now=$(date +%s%N)

old_iface=""
old_time=""
old_rx=""
old_tx=""
if [ -r "$cache" ]; then
	read -r old_iface old_time old_rx old_tx <"$cache" 2>/dev/null || true
fi

printf '%s %s %s %s\n' "$iface" "$now" "$rx" "$tx" >"$cache"

if [ -z "$old_time" ] || [ "$old_iface" != "$iface" ] || [ "$old_rx" -ge "$rx" ]; then
	printf '%s\n' "—"
	exit 0
fi

awk -v dt="$((now - old_time))" \
	-v drx="$((rx - old_rx))" \
	-v dtx="$((tx - old_tx))" '
function fmt(bps) {
	if (bps >= 1048576) return sprintf("%.1fMB/s", bps / 1048576)
	if (bps >= 1024)    return sprintf("%.0fKB/s", bps / 1024)
	return sprintf("%.0fB/s", bps)
}
BEGIN {
	if (dt <= 0) { print "—"; exit }
	printf "%s⬇ %s⬆\n", fmt(drx * 1e9 / dt), fmt(dtx * 1e9 / dt)
}'
