#!/bin/sh
# dunst 动作菜单包装器 —— dunst 的 dmenu 设置指向本脚本（见同目录的 dunstrc）
#
# dunst 会在下面两种情况下把候选列表（动作项 "#动作名 (摘要) [id,动作键]"、通知正文里的链接）
# 从标准输入喂给这个脚本：
#   1. 左键点击一条「没有默认动作」的通知（dunstrc 里 mouse_left_click = do_action）
#   2. 手动执行 dunstctl context
#
# 本脚本做的事：
#   - 在候选列表最前面插一条「↗ 打开「应用名」」，选中它 → 跳到发出这条通知的程序窗口
#   - 其它选择原样写到标准输出，交回 dunst（由 dunst 触发动作 / 用浏览器打开链接）
#
# 依赖：
#   wmctrl（推荐，次选 xdotool）：激活窗口；没有它就不插「打开」项，菜单退化成 dunst 原生行为
#     Debian / Ubuntu: sudo apt install wmctrl
#     Arch:            sudo pacman -S wmctrl
#
# 注意：窗口能不能**真的**被切到前台，还取决于窗口管理器是否响应 _NET_ACTIVE_WINDOW：
#   本仓库的 dwm 打了 focusonnetactive（见 patches/README.md），所以 wmctrl -i -a 就是切窗口；
#   上游 dwm / 没打这个补丁的配置只会给窗口置「紧急」标记（边框闪一下）。
#
# 应用名从哪来：
#   dunst 的菜单输入里没有应用名，所以由同目录的 dunst-sender.sh（dunstrc 里的 [sender] 规则）
#   在通知显示时把「通知 id → 应用名 / desktop-entry」记到 ~/.cache/dunst-sender.tsv，
#   这里再查表：动作项里带 id（[123,default]）就精确查，只有链接的退化成「最近一条」。
#
# 调试：
#   DUNST_MENU_DRY=1               只在标准错误打印菜单，不真的弹菜单
#   DUNST_MENU_LOG=/path/to/log    自定义日志（默认 ~/.cache/dunst-menu.log）
#   DUNST_MENU_NO_LOG=1            不写日志

set -u

have() { command -v "$1" >/dev/null 2>&1; }

# ---- 日志 ---------------------------------------------------------------- #

log() {
	[ -n "${DUNST_MENU_NO_LOG:-}" ] && return 0
	_log_file="${DUNST_MENU_LOG:-${HOME}/.cache/dunst-menu.log}"
	mkdir -p "$(dirname "${_log_file}")" 2>/dev/null || return 0
	printf '%s %s\n' "$(date '+%F %T')" "$*" >>"${_log_file}" 2>/dev/null || return 0
	return 0
}

# 菜单程序：优先 rofi（与 dwm 的启动器同款），回退 dmenu
if have rofi; then
	menu_cmd="rofi -dmenu -i -p dunst"
elif have dmenu; then
	menu_cmd="dmenu -i -p dunst"
else
	menu_cmd=""
fi

# ---- 1. 读入 dunst 喂过来的候选列表 -------------------------------------- #

menu_input="$(cat)"

# ---- 2. 定位这条通知来自哪个应用 ----------------------------------------- #

# 有动作的通知会在候选串里带上通知 id（[123,default]），用它去 dunst-sender.tsv
# 精确查应用名；只有链接的通知没有 id，退化成「最近一条通知」（同一屏堆了好几条时可能不准）。
state="${DUNST_SENDER_STATE:-${XDG_CACHE_HOME:-${HOME}/.cache}/dunst-sender.tsv}"
notif_id="$(printf '%s\n' "${menu_input}" | sed -n 's/.*\[\([0-9][0-9]*\),[^]]*\].*/\1/p' | head -n1)"

lookup=""
if [ -f "${state}" ]; then
	[ -n "${notif_id}" ] && lookup="$(awk -F'\t' -v id="${notif_id}" '$1 == id { line = $0 } END { print line }' "${state}")"
	[ -n "${lookup}" ] || lookup="$(tail -n1 "${state}")"
fi

appname="$(printf '%s' "${lookup}" | cut -f2)"
desktop_entry="$(printf '%s' "${lookup}" | cut -f3)"
log "通知 id=${notif_id:-无} → 应用「${appname:-未知}」（desktop-entry：${desktop_entry:-无}）"

# ---- 3. 应用名 → 窗口类名候选 -------------------------------------------- #

# .desktop 文件里的 StartupWMClass 最准（应用名常带空格 / 本地化，和 WM_CLASS 对不上）
startup_class=""
if [ -n "${desktop_entry}" ]; then
	desktop_dirs="${XDG_DATA_HOME:-${HOME}/.local/share}/applications:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
	startup_class="$(printf '%s\n' "${desktop_dirs}" | tr ':' '\n' | while IFS= read -r dir; do
		file="${dir}/${desktop_entry}.desktop"
		[ -f "${file}" ] || continue
		cls="$(sed -n 's/^StartupWMClass=//p' "${file}" | head -n1)"
		[ -n "${cls}" ] && { printf '%s' "${cls}"; break; }
	done)"
fi

candidates="${startup_class}
${appname}
$(printf '%s' "${appname}" | tr -d ' ')"

# ---- 4. 在窗口列表里找目标窗口 ------------------------------------------- #

window_list=""
if have wmctrl; then
	window_list="$(wmctrl -lx 2>/dev/null || true)"
fi

# $1 候选类名（已小写、无空格） $2 1=精确匹配 instance/class，0=子串匹配
match_window() {
	if [ -n "${window_list}" ]; then
		printf '%s\n' "${window_list}" | awk -v pat="$1" -v exact="$2" '
			BEGIN { pat = tolower(pat) }
			{
				cls = tolower($3)          # 第 3 列是 WM_CLASS：instance.class
				split(cls, part, ".")
				if (exact) {
					if (part[1] == pat || part[2] == pat) { print $1; exit }
				} else if (index(cls, pat)) {
					print $1; exit
				}
			}'
		return 0
	fi
	have xdotool && xdotool search --class "$1" 2>/dev/null | head -n1
}

window_id=""
for mode in 1 0; do
	[ -n "${window_id}" ] && break
	window_id="$(printf '%s\n' "${candidates}" | while IFS= read -r cand; do
		norm="$(printf '%s' "${cand}" | tr 'A-Z' 'a-z' | tr -d ' ')"
		[ -n "${norm}" ] || continue
		hit="$(match_window "${norm}" "${mode}")"
		[ -n "${hit}" ] && { printf '%s' "${hit}"; break; }
	done)"
done

activate_window() {
	if have wmctrl; then
		wmctrl -i -a "$1" && return 0
	elif have xdotool; then
		xdotool windowactivate --sync "$1" 2>/dev/null && return 0
	fi
	return 1
}

# ---- 5. 组装菜单 --------------------------------------------------------- #

label=""
if [ -n "${appname}" ] && [ -n "${window_id}" ]; then
	label="↗ 打开「${appname}」"
	menu_input="${label}
${menu_input}"
fi

# 没有目标窗口（应用已退出 / 没装 wmctrl）时只记一笔日志，菜单照常显示
[ -z "${label}" ] && log "未插入「打开」项（应用：${appname:-未知}，窗口：${window_id:-未找到}）"

# ---- 6. 弹菜单并处理选择 ------------------------------------------------- #

if [ -n "${DUNST_MENU_DRY:-}" ]; then
	printf 'appname=%s\nwindow_id=%s\nmodes=%s\nmenu:\n%s\n' \
		"${appname}" "${window_id}" "wmctrl=$(have wmctrl && echo yes || echo no)" "${menu_input}" >&2
	exit 0
fi

[ -n "${menu_cmd}" ] || { log "未找到 rofi / dmenu，跳过菜单"; exit 0; }

# ${menu_cmd} 故意不加引号：这里就是要按空格拆成命令 + 参数
# shellcheck disable=SC2086
choice="$(printf '%s\n' "${menu_input}" | ${menu_cmd} 2>/dev/null)" || exit 0
[ -n "${choice}" ] || exit 0

if [ -n "${label}" ] && [ "${choice}" = "${label}" ]; then
	if activate_window "${window_id}"; then
		log "跳到「${appname}」（窗口 ${window_id}）"
	else
		log "激活失败：「${appname}」（窗口 ${window_id}）"
		have notify-send \
			&& notify-send -u low -t 3000 "dunst" "没能激活「${appname}」的窗口" >/dev/null 2>&1
	fi
	exit 0
fi

# 其余选择交回 dunst（'#' 开头是动作项，其它按链接打开）
printf '%s\n' "${choice}"
log "交回 dunst：${choice}"
