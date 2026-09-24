#!/bin/sh
# 由 dunstrc 里的 [sender] 规则在「每条通知显示时」调用，把发送方记到一张小表里
#
# 为什么需要它：
#   dunst 弹动作菜单时喂给 dmenu 的内容只有动作项和链接，不带应用名；
#   dunstctl history 里又只有「已经关掉」的通知，正在显示的查不到。
#   所以在通知显示时先记一笔（DUNST_ID ↔ 应用名），点击时再查表。
#
# dunst 通过环境变量把通知信息传进来，这里用到：
#   DUNST_ID              通知 id（动作项 [id,key] 里的那个 id，两边能对上）
#   DUNST_APP_NAME        应用名（如 "Telegram Desktop"）
#   DUNST_DESKTOP_ENTRY   .desktop 名（如 org.telegram.desktop，用来查 StartupWMClass）
#
# 状态文件：~/.cache/dunst-sender.tsv（只留最近 30 条），可用 DUNST_SENDER_STATE 覆盖

set -u

state="${DUNST_SENDER_STATE:-${XDG_CACHE_HOME:-${HOME}/.cache}/dunst-sender.tsv}"
dir="$(dirname "${state}")"

mkdir -p "${dir}" 2>/dev/null || exit 0

printf '%s\t%s\t%s\n' "${DUNST_ID:--}" "${DUNST_APP_NAME:-}" "${DUNST_DESKTOP_ENTRY:-}" \
	>>"${state}" 2>/dev/null || exit 0

# 只留最近 30 条，避免文件无限增长
tmp="$(mktemp "${dir}/dunst-sender.XXXXXX" 2>/dev/null)" || exit 0
tail -n 30 "${state}" >"${tmp}" 2>/dev/null && mv -f "${tmp}" "${state}" 2>/dev/null

exit 0
