#!/bin/sh
# dwm 启动时自动执行的非阻塞脚本
#
# 由 dwm.c 的 runautostart() 调用，需部署到 ~/.dwm/autostart.sh 且具有可执行权限。
# 若需要「阻塞执行」的初始化步骤，请另建 ~/.dwm/autostart_blocking.sh。
#
# 可用 WALLPAPER_DIR 环境变量覆盖壁纸目录（默认 ~/images）。

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

# 输入法
launch fcitx5 fcitx5 -d

# 截图工具
launch Snipaste Snipaste
