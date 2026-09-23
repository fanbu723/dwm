#!/bin/sh
# dwm 启动时自动执行的非阻塞脚本
#
# 由 dwm.c 的 runautostart() 调用，需部署到 ~/.dwm/autostart.sh 且具有可执行权限。
# 若需要「阻塞执行」的初始化步骤，请另建 ~/.dwm/autostart_blocking.sh。
#
# 可用 WALLPAPER_DIR 环境变量覆盖壁纸目录（默认 ~/images）。
# 可用 LOCKER 环境变量覆盖锁屏命令（挑选逻辑见同目录的 scripts/lock.sh）。
# 可用 SCREEN_TIMEOUT 环境变量覆盖空闲熄屏秒数（默认 900 = 15 分钟，设 0 表示不熄屏）。

# 本脚本所在目录（部署后即 ~/.dwm），用于定位同目录下的 scripts/lock.sh
script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

# launch <进程名> [完整命令...]
# 未安装则静默跳过，已在运行则不重复启动
launch() {
	name=$1
	shift
	command -v "$name" >/dev/null 2>&1 || return 0
	pgrep -x "$name" >/dev/null 2>&1 && return 0
	"$@" >/dev/null 2>&1 &
}

# 壁纸
wallpaper_dir="${WALLPAPER_DIR:-$HOME/images}"
if [ -d "$wallpaper_dir" ]; then
	launch feh feh --recursive --randomize --bg-fill "$wallpaper_dir"
else
	printf '%s\n' "autostart.sh: 壁纸目录不存在，已跳过：$wallpaper_dir" >&2
fi

# 窗口合成器（透明 / 阴影）
launch picom picom

# 通知守护进程
launch dunst dunst -b

# 状态栏
launch dwmblocks dwmblocks

# 空闲熄屏 / DPMS：这是 X 层的空闲计时，dconf 的电源策略只管 GNOME 会话，
# dwm 下要看这里（以及 GDM 等登录界面，那边由 dconf 负责）。
# 默认空闲 15 分钟（900 秒）黑屏、紧接着 DPMS 关屏；两件事都会触发下面的 xss-lock 锁屏。
screen_timeout="${SCREEN_TIMEOUT:-900}"
if command -v xset >/dev/null 2>&1; then
	if [ "$screen_timeout" = "0" ]; then
		xset s off
		xset -dpms
	else
		xset s "$screen_timeout" "$screen_timeout"
		# 只做「关屏」，不走 standby / suspend 阶段
		xset +dpms dpms 0 0 "$screen_timeout"
	fi
else
	printf '%s\n' "autostart.sh: 未找到 xset，已跳过空闲熄屏设置（Arch: sudo pacman -S xorg-xset；Debian/Ubuntu: sudo apt install x11-xserver-utils）" >&2
fi

# 锁屏：xss-lock 监听空闲 / DPMS / 挂起事件，触发时调用 scripts/lock.sh
# （锁屏程序在 lock.sh 里挑选；dwm 的 Super+Escape 键位调用的是同一个脚本）
locker_script="${script_dir}/scripts/lock.sh"

if ! command -v xss-lock >/dev/null 2>&1; then
	printf '%s\n' "autostart.sh: 未安装 xss-lock，无法自动锁屏（Arch: sudo pacman -S xss-lock；Debian/Ubuntu: sudo apt install xss-lock）" >&2
elif [ ! -x "$locker_script" ]; then
	printf '%s\n' "autostart.sh: 锁屏脚本不存在或不可执行，已跳过自动锁屏：${locker_script}" >&2
else
	launch xss-lock xss-lock -- "$locker_script"
fi

# 输入法
launch fcitx5 fcitx5 -d

# 截图工具
launch Snipaste Snipaste
