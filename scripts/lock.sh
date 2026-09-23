#!/bin/sh
# 锁屏脚本：由 dwm 的键位（src/config.h 的 LOCK_CMD）与 xss-lock（scripts/autostart.sh）
# 共同调用，锁屏程序的挑选逻辑只写在这一处。
#
# 挑选顺序：LOCKER 环境变量 → betterlockscreen → i3lock → slock
#   例：LOCKER="i3lock -n -c 222222"   或   LOCKER="betterlockscreen -l"
# 部署位置：~/.dwm/scripts/lock.sh（install.sh 会补齐可执行权限）

lockcmd="${LOCKER:-}"
if [ -z "$lockcmd" ]; then
	if command -v betterlockscreen >/dev/null 2>&1; then
		lockcmd="betterlockscreen -l"
	elif command -v i3lock >/dev/null 2>&1; then
		lockcmd="i3lock"
	elif command -v slock >/dev/null 2>&1; then
		lockcmd="slock"
	fi
fi

if [ -z "$lockcmd" ]; then
	printf '%s\n' "lock.sh: 未找到锁屏程序（slock / i3lock / betterlockscreen），请先安装其中一个" >&2
	exit 1
fi

# 故意不加引号：lockcmd 可能自带参数（如 "betterlockscreen -l"），
# 需要按空格拆成多个参数；exec 后本脚本的进程直接变成锁屏程序，
# 这样 xss-lock 监视的进程与真正的锁屏进程是同一个。
# shellcheck disable=SC2086
exec $lockcmd
