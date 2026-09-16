#!/usr/bin/env bash
#
# dwm + dwmblocks 一键安装脚本（Arch Linux）
#
#   编译安装 dwm / dwmblocks → 部署自启脚本与状态栏脚本
#   → 安装 XSession 会话文件 → 配置 fcitx5 + 雾凇拼音
#
# 用法：./install.sh --help
#
# 设计原则：
#   - 幂等：重复执行不会产生重复内容，改动过的文件会先备份再覆盖
#   - 安全：默认只写用户级配置，不碰 /etc（除非显式 --system-env）
#   - 可预览：--dry-run 只打印不执行
#
set -Eeuo pipefail

# --------------------------------------------------------------------------- #
# 常量
# --------------------------------------------------------------------------- #

SCRIPT_NAME="$(basename -- "${BASH_SOURCE[0]}")"
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

PREFIX="/usr/local"
MANPREFIX="${PREFIX}/share/man"
XSESSIONS_DIR="/usr/share/xsessions"
AUTOSTART_DIR="${HOME}/.dwm"
RIME_DIR="${HOME}/.local/share/fcitx5/rime"
ENVD_DIR="${HOME}/.config/environment.d"
XPROFILE="${HOME}/.xprofile"

VERSION="unknown"
[[ -r "${REPO_DIR}/config.mk" ]] \
	&& VERSION="$(sed -n 's/^VERSION[[:space:]]*=[[:space:]]*//p' "${REPO_DIR}/config.mk" | head -n1)"

# 构建依赖 / 运行依赖（官方仓库）
PKGS_BUILD=(base-devel libx11 libxinerama libxft freetype2 fontconfig libxrender)
PKGS_RUNTIME=(kitty rofi feh picom dunst)
PKGS_SCRIPT=(brightnessctl alsa-utils iproute2 gawk)
PKGS_IME=(fcitx5-im fcitx5-rime)
# AUR（安装失败不中断）
PKGS_AUR=(rime-ice-git maplemono-cn)

# --------------------------------------------------------------------------- #
# 参数
# --------------------------------------------------------------------------- #

DRY_RUN=false
ASSUME_YES=false
WITH_DEPS=true
WITH_DWM=true
WITH_DWMBLOCKS=true
WITH_IME=true
USE_SYSTEM_ENV=false
DO_UNINSTALL=false

# --------------------------------------------------------------------------- #
# 输出
# --------------------------------------------------------------------------- #

if [[ -t 1 ]]; then
	C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
	C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
	C_BLUE=$'\033[34m'; C_CYAN=$'\033[36m'; C_MAGENTA=$'\033[35m'
else
	C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""
	C_BLUE=""; C_CYAN=""; C_MAGENTA=""
fi

step()  { printf '\n%s==>%s %s%s%s\n' "$C_MAGENTA" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
log()   { printf '%s  ·%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()    { printf '%s  ✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()  { printf '%s  !%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()   { printf '\n%s  ✗ %s%s\n' "$C_RED" "$*" "$C_RESET" >&2; exit 1; }

trap 'printf "\n%s  ✗ 第 %s 行执行失败，安装已中止%s\n" "$C_RED" "${LINENO}" "$C_RESET" >&2' ERR

usage() {
	cat <<EOF
${C_BOLD}${SCRIPT_NAME}${C_RESET} — 安装 dwm ${VERSION} + dwmblocks + 配套配置

${C_BOLD}用法${C_RESET}
  ./${SCRIPT_NAME} [选项]

${C_BOLD}选项${C_RESET}
  -n, --dry-run            只打印将要执行的命令，不做任何修改
  -y, --yes                所有询问自动回答 yes
      --no-deps            跳过依赖安装
      --no-dwm             跳过 dwm 编译安装
      --no-dwmblocks       跳过 dwmblocks 编译安装
      --no-ime             跳过 fcitx5 / 雾凇拼音配置
      --system-env         输入法环境变量写入 /etc/environment（需 root，影响全局）
      --prefix DIR         安装前缀（默认 ${PREFIX}）
      --autostart-dir DIR  自启脚本部署目录（默认 ~/.dwm）
      --uninstall          卸载 dwm / dwmblocks / 会话文件 / 自启目录
  -h, --help               显示本帮助

${C_BOLD}示例${C_RESET}
  ./${SCRIPT_NAME} --dry-run          # 先看看会做什么
  ./${SCRIPT_NAME}                    # 完整安装
  ./${SCRIPT_NAME} --no-deps --no-ime # 只编译安装，不动依赖和输入法
  ./${SCRIPT_NAME} --uninstall        # 卸载

${C_BOLD}安装后${C_RESET}
  注销并重新登录，在登录界面选择 "Dwm" 会话。
EOF
}

parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			-n|--dry-run)       DRY_RUN=true ;;
			-y|--yes)           ASSUME_YES=true ;;
			--no-deps)          WITH_DEPS=false ;;
			--no-dwm)           WITH_DWM=false ;;
			--no-dwmblocks)     WITH_DWMBLOCKS=false ;;
			--no-ime)           WITH_IME=false ;;
			--system-env)       USE_SYSTEM_ENV=true ;;
			--prefix)           PREFIX="${2:?--prefix 需要一个参数}"; MANPREFIX="${PREFIX}/share/man"; shift ;;
			--autostart-dir)    AUTOSTART_DIR="${2:?--autostart-dir 需要一个参数}"; shift ;;
			--uninstall)        DO_UNINSTALL=true ;;
			-h|--help)          usage; exit 0 ;;
			*)                  usage; die "未知参数：$1" ;;
		esac
		shift
	done
}

# --------------------------------------------------------------------------- #
# 基础工具
# --------------------------------------------------------------------------- #

have() { command -v "$1" >/dev/null 2>&1; }

# 尊重 --dry-run 的命令执行
run() {
	if [[ $DRY_RUN == true ]]; then
		printf '%s  [dry-run]%s %s\n' "$C_CYAN" "$C_RESET" "$(printf '%q ' "$@")"
	else
		"$@"
	fi
}

SUDO=()
setup_sudo() {
	if [[ "${EUID}" -eq 0 ]]; then
		SUDO=()
		return
	fi
	have sudo || die "需要 root 或 sudo 权限来写入 ${PREFIX} 与 ${XSESSIONS_DIR}"
	if [[ $DRY_RUN == false ]]; then
		sudo -v || die "sudo 认证失败"
	fi
	SUDO=(sudo)
}

as_root() {
	if [[ ${#SUDO[@]} -gt 0 ]]; then
		run "${SUDO[@]}" "$@"
	else
		run "$@"
	fi
}

confirm() {
	local prompt="$1"
	[[ $ASSUME_YES == true ]] && return 0
	[[ $DRY_RUN == true ]] && { log "[dry-run] 询问：${prompt} → yes"; return 0; }
	[[ -t 0 ]] || return 0
	local reply
	read -r -p "${prompt} [y/N] " reply
	[[ "$reply" =~ ^[Yy]$ ]]
}

# 写入文本内容（幂等 + 自动备份）
write_content() {
	local path="$1" content="$2" mode="${3:-644}" tmp

	if [[ $DRY_RUN == true ]]; then
		printf '%s  [dry-run]%s 写入 %s\n' "$C_CYAN" "$C_RESET" "$path"
		return 0
	fi

	tmp="$(mktemp)"
	printf '%s\n' "$content" >"$tmp"

	if [[ -f "$path" ]] && ! cmp -s "$tmp" "$path"; then
		local bak="${path}.bak.$(date +%Y%m%d%H%M%S)"
		cp -a -- "$path" "$bak"
		warn "原文件已备份 → ${bak}"
	fi

	install -Dm"$mode" "$tmp" "$path"
	rm -f "$tmp"
	ok "写入 ${path}"
}

# 安装单个文件（幂等 + 自动备份）
install_file() {
	local src="$1" dst="$2" mode="${3:-644}"

	if [[ $DRY_RUN == true ]]; then
		printf '%s  [dry-run]%s 安装 %s → %s (mode %s)\n' "$C_CYAN" "$C_RESET" "$src" "$dst" "$mode"
		return 0
	fi

	[[ -f "$src" ]] || die "源文件不存在：${src}"

	if [[ -f "$dst" ]] && ! cmp -s "$src" "$dst"; then
		local bak="${dst}.bak.$(date +%Y%m%d%H%M%S)"
		cp -a -- "$dst" "$bak"
		warn "原文件已备份 → ${bak}"
	fi

	install -Dm"$mode" "$src" "$dst"
}

# --------------------------------------------------------------------------- #
# 步骤 1：环境检查
# --------------------------------------------------------------------------- #

preflight() {
	step "环境检查"

	[[ -f "${REPO_DIR}/dwm.c" && -f "${REPO_DIR}/Makefile" ]] \
		|| die "请在仓库根目录运行本脚本（当前：${REPO_DIR}）"

	have make || die "未找到 make，请先安装 base-devel"
	have cc || have gcc || die "未找到 C 编译器，请先安装 base-devel"

	if [[ -r /etc/os-release ]]; then
		# shellcheck disable=SC1091
		. /etc/os-release
		log "系统：${PRETTY_NAME:-unknown}"
		[[ "${ID:-}" == "arch" || "${ID_LIKE:-}" == *arch* ]] \
			|| warn "非 Arch 系发行版，依赖安装步骤可能不适用（可加 --no-deps 跳过）"
	else
		warn "无法识别发行版（缺少 /etc/os-release）"
	fi

	log "仓库：${REPO_DIR}"
	log "dwm 版本：${VERSION}   安装前缀：${PREFIX}"
	[[ $DRY_RUN == true ]] && warn "DRY-RUN 模式：不会真正修改任何文件"
	ok "环境检查通过"
}

# --------------------------------------------------------------------------- #
# 步骤 2：依赖
# --------------------------------------------------------------------------- #

aur_helper() {
	if have yay; then
		echo yay
	elif have paru; then
		echo paru
	fi
}

install_deps() {
	step "安装依赖"

	if ! have pacman; then
		warn "未找到 pacman，跳过依赖安装"
		return 0
	fi

	local pacman_args=(-S --needed)
	[[ $ASSUME_YES == true ]] && pacman_args+=(--noconfirm)

	log "官方仓库：${PKGS_BUILD[*]} ${PKGS_RUNTIME[*]} ${PKGS_SCRIPT[*]} ${PKGS_IME[*]}"
	as_root pacman "${pacman_args[@]}" "${PKGS_BUILD[@]}" "${PKGS_RUNTIME[@]}" "${PKGS_SCRIPT[@]}" "${PKGS_IME[@]}"

	if [[ $WITH_IME == false ]]; then
		log "已指定 --no-ime，跳过 AUR 输入法方案"
		ok "依赖处理完成"
		return 0
	fi

	local helper
	helper="$(aur_helper)"
	if [[ -z "$helper" ]]; then
		warn "未找到 yay / paru，跳过 AUR 包：${PKGS_AUR[*]}"
		ok "依赖处理完成"
		return 0
	fi

	log "AUR（${helper}）：${PKGS_AUR[*]}"
	local aur_args=(-S --needed)
	if [[ $ASSUME_YES == true ]]; then
		aur_args+=(--noconfirm)
	elif [[ "$helper" == "yay" ]]; then
		# 避免 yay 交互式询问 cleanBuild / diff
		aur_args+=(--answerclean None --answerdiff None --answeredit None)
	fi

	# AUR 包失败不中断安装（字体 / 方案缺失只影响显示效果）
	run "$helper" "${aur_args[@]}" "${PKGS_AUR[@]}" \
		|| warn "AUR 包安装失败，可稍后手动执行：${helper} -S ${PKGS_AUR[*]}"

	ok "依赖处理完成"
}

# --------------------------------------------------------------------------- #
# 步骤 3：编译安装 dwm / dwmblocks
# --------------------------------------------------------------------------- #

build_dwm() {
	step "编译 dwm ${VERSION}"
	run make -C "${REPO_DIR}" clean
	run make -C "${REPO_DIR}"
	ok "dwm 编译完成"

	step "安装 dwm → ${PREFIX}/bin"
	as_root make -C "${REPO_DIR}" install PREFIX="${PREFIX}" MANPREFIX="${MANPREFIX}"
	ok "dwm 已安装"
}

build_dwmblocks() {
	step "编译 dwmblocks"
	[[ -f "${REPO_DIR}/dwmblocks/blocks.h" ]] \
		|| warn "blocks.h 不存在，将使用上游默认模块定义（不影响 dwm 本身）"
	run make -C "${REPO_DIR}/dwmblocks" clean
	run make -C "${REPO_DIR}/dwmblocks"
	ok "dwmblocks 编译完成"

	step "安装 dwmblocks → ${PREFIX}/bin"
	as_root make -C "${REPO_DIR}/dwmblocks" install PREFIX="${PREFIX}"
	ok "dwmblocks 已安装"
}

# --------------------------------------------------------------------------- #
# 步骤 4：部署自启脚本与状态栏脚本
# --------------------------------------------------------------------------- #

sync_blocks_path() {
	# blocks.h 中的脚本路径是相对 $HOME 的硬编码路径，若部署目录不同需同步替换
	local old_prefix='~/.dwm' escaped
	[[ "$AUTOSTART_DIR" == "${HOME}/.dwm" ]] && return 0

	escaped="$(printf '%s' "$AUTOSTART_DIR" | sed 's/[&|\\]/\\&/g')"
	log "同步 blocks.h 中的脚本路径：${old_prefix} → ${AUTOSTART_DIR}"
	run sed -i "s|${old_prefix}|${escaped}|g" "${REPO_DIR}/dwmblocks/blocks.h"
	warn "blocks.h 已修改，需要重新编译 dwmblocks"
}

deploy_autostart() {
	step "部署自启脚本 → ${AUTOSTART_DIR}"

	# dwm 的查找顺序：$XDG_DATA_HOME/dwm → ~/.local/share/dwm → ~/.dwm
	# 只要更靠前的目录存在，就会忽略 ~/.dwm
	local xdg_dwm="${XDG_DATA_HOME:-${HOME}/.local/share}/dwm"
	if [[ -d "$xdg_dwm" && "$AUTOSTART_DIR" != "$xdg_dwm" ]]; then
		warn "检测到 ${xdg_dwm} 存在，dwm 会优先使用它而忽略 ${AUTOSTART_DIR}"
		warn "若希望使用 ${AUTOSTART_DIR}，请先移除该目录（或用 --autostart-dir ${xdg_dwm}）"
	fi

	run mkdir -p "${AUTOSTART_DIR}/scripts"

	install_file "${REPO_DIR}/autostart.sh" "${AUTOSTART_DIR}/autostart.sh" 755

	local s
	for s in "${REPO_DIR}"/scripts/*.sh; do
		[[ -e "$s" ]] || continue
		install_file "$s" "${AUTOSTART_DIR}/scripts/$(basename -- "$s")" 755
	done

	ok "自启脚本与状态栏脚本已就绪"

	[[ -f "${AUTOSTART_DIR}/autostart_blocking.sh" ]] \
		|| log "提示：可选地创建 ${AUTOSTART_DIR}/autostart_blocking.sh（先于 autostart.sh 阻塞执行）"

	sync_blocks_path
}

# --------------------------------------------------------------------------- #
# 步骤 5：XSession 会话文件
# --------------------------------------------------------------------------- #

install_session() {
	step "安装 XSession 会话文件"
	as_root install -Dm644 "${REPO_DIR}/dwm.desktop" "${XSESSIONS_DIR}/dwm.desktop"
	ok "已安装 ${XSESSIONS_DIR}/dwm.desktop"
}

# --------------------------------------------------------------------------- #
# 步骤 6：输入法（fcitx5 + 雾凇拼音）
# --------------------------------------------------------------------------- #

rime_config() {
	cat <<'EOF'
patch:
  # 仅使用「雾凇拼音」的默认配置，配置此行即可
  __include: rime_ice_suggestion:/
  # 以下根据自己所需自行定义，仅做参考。
  # 针对对应处方的定制条目，请使用 <recipe>.custom.yaml 中配置，例如 rime_ice.custom.yaml
  __patch:
    key_binder/bindings/+:
      # 开启逗号句号翻页
      - { when: paging, accept: comma, send: Page_Up }
      - { when: has_menu, accept: period, send: Page_Down }
    menu/page_size: 9
EOF
}

# environment.d 格式：纯 KEY=VALUE，不能有 export
env_d_content() {
	cat <<'EOF'
# 由 dwm/install.sh 生成 —— fcitx5 输入法环境变量
# GLFW_IM_MODULE 必须是 ibus：GLFW 只实现了 ibus 协议
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus
EOF
}

# shell 片段格式：需要 export
env_shell_content() {
	cat <<'EOF'
# 由 dwm/install.sh 生成 —— fcitx5 输入法环境变量
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export SDL_IM_MODULE=fcitx
export GLFW_IM_MODULE=ibus
EOF
}

setup_ime() {
	step "配置输入法（fcitx5 + 雾凇拼音）"

	run mkdir -p "${RIME_DIR}"
	write_content "${RIME_DIR}/default.custom.yaml" "$(rime_config)"

	# 与已有配置文件合并：只追加一次，避免重复
	append_shell_block "${XPROFILE}" "$(env_shell_content)"
	write_content "${ENVD_DIR}/10-ime.conf" "$(env_d_content)"

	if [[ $USE_SYSTEM_ENV == true ]]; then
		append_system_env
	fi

	ok "输入法配置完成"
}

# 向 shell 片段文件追加一段带标记的配置（可重复执行）
append_shell_block() {
	local path="$1" content="$2"
	local begin="# >>> dwm install.sh: ime >>>"
	local end="# <<< dwm install.sh: ime <<<"

	if [[ $DRY_RUN == true ]]; then
		printf '%s  [dry-run]%s 追加输入法环境变量 → %s\n' "$C_CYAN" "$C_RESET" "$path"
		return 0
	fi

	if [[ -f "$path" ]] && grep -qF "$begin" "$path"; then
		ok "${path} 已包含输入法配置，跳过"
		return 0
	fi

	{
		printf '\n%s\n' "$begin"
		printf '%s\n' "$content"
		printf '%s\n' "$end"
	} >>"$path"

	ok "追加输入法环境变量 → ${path}"
}

append_system_env() {
	local path="/etc/environment"
	local begin="# >>> dwm install.sh: ime >>>"
	local end="# <<< dwm install.sh: ime <<<"

	if [[ $DRY_RUN == false ]] && [[ -f "$path" ]] && grep -qE '^(GTK_IM_MODULE|XMODIFIERS)=' "$path"; then
		warn "${path} 中已存在输入法环境变量，跳过（避免重复）"
		return 0
	fi

	if [[ $DRY_RUN == true ]]; then
		printf '%s  [dry-run]%s 追加输入法环境变量 → %s\n' "$C_CYAN" "$C_RESET" "$path"
		return 0
	fi

	# 注意：重定向必须由 root 执行，因此用 tee 而非 "sudo echo >>"
	printf '\n%s\n%s\n%s\n' "$begin" "$(env_d_content)" "$end" \
		| sudo tee -a "$path" >/dev/null
	ok "追加输入法环境变量 → ${path}（重新登录后生效）"
}

# --------------------------------------------------------------------------- #
# 卸载
# --------------------------------------------------------------------------- #

do_uninstall() {
	step "卸载 dwm / dwmblocks"

	as_root rm -f "${PREFIX}/bin/dwm" "${PREFIX}/bin/dwmblocks" \
		"${MANPREFIX}/man1/dwm.1"
	ok "已删除二进制与 man page"

	as_root rm -f "${XSESSIONS_DIR}/dwm.desktop"
	ok "已删除会话文件"

	if [[ -d "$AUTOSTART_DIR" ]] && confirm "删除自启目录 ${AUTOSTART_DIR}？"; then
		run rm -rf -- "$AUTOSTART_DIR"
		ok "已删除 ${AUTOSTART_DIR}"
	fi

	warn "以下内容需要你手动确认是否删除（避免误删你自己的配置）："
	log "${ENVD_DIR}/10-ime.conf（输入法环境变量）"
	log "${XPROFILE} 中 'dwm install.sh: ime' 标记之间的内容"
	log "/etc/environment 中 'dwm install.sh: ime' 标记之间的内容（若用过 --system-env）"
	log "${RIME_DIR}/default.custom.yaml（Rime 方案配置）"

	step "卸载完成"
}

# --------------------------------------------------------------------------- #
# 主流程
# --------------------------------------------------------------------------- #

main() {
	parse_args "$@"

	printf '%s%s%s — dwm %s 安装脚本\n' "$C_BOLD" "$SCRIPT_NAME" "$C_RESET" "$VERSION"

	setup_sudo

	if [[ $DO_UNINSTALL == true ]]; then
		do_uninstall
		exit 0
	fi

	preflight

	if [[ $WITH_DEPS == true ]]; then
		install_deps
	fi
	if [[ $WITH_DWM == true ]]; then
		build_dwm
	fi
	if [[ $WITH_DWMBLOCKS == true ]]; then
		build_dwmblocks
	fi

	deploy_autostart
	install_session

	if [[ $WITH_IME == true ]]; then
		setup_ime
	fi

	step "全部完成"
	cat <<EOF

下一步：
  1. 注销并重新登录，在登录界面选择 "Dwm" 会话
  2. 首次启动后确认状态栏正常：pkill -RTMIN+11 dwmblocks 可手动刷新音量/亮度
  3. 修改 config.h 或 blocks.h 后需重新执行 ./${SCRIPT_NAME}（或手动 make）

EOF

	if [[ $WITH_IME == true && $USE_SYSTEM_ENV == false ]]; then
		log "输入法环境变量写入的是用户级配置，若某些应用仍不生效可尝试：./${SCRIPT_NAME} --system-env"
	fi
}

main "$@"
