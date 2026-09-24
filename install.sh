#!/usr/bin/env bash
#
# dwm + dwmblocks 一键安装脚本（Arch Linux / Debian / Ubuntu）
#
#   编译安装 dwm / dwmblocks → 部署自启脚本与状态栏脚本
#   → 安装 XSession 会话文件 → 配置 fcitx5 + 雾凇拼音 → 部署 zsh（oh-my-zsh）
#
# 支持发行版：
#   - Arch 系：pacman + yay/paru（AUR 提供雾凇拼音与 Maple Mono 字体）
#   - Debian / Ubuntu 系：apt（雾凇拼音与字体改从上游 GitHub 发布包下载）
#
# 用法：./install.sh --help
#
# 设计原则：
#   - 幂等：重复执行不会产生重复内容，改动过的文件会先备份再覆盖
#   - 安全：默认只写用户级配置，不碰 /etc（除非显式 --system-env）
#   - 可预览：--dry-run 只打印不执行
#   - 可降级：可选依赖（字体 / 雾凇拼音 / AUR）失败只告警，不中断安装
#
set -Eeuo pipefail

# --------------------------------------------------------------------------- #
# 常量
# --------------------------------------------------------------------------- #

SCRIPT_NAME="$(basename -- "${BASH_SOURCE[0]}")"
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${REPO_DIR}/src"           # dwm 源码
BLOCKS_DIR="${REPO_DIR}/dwmblocks"  # 状态栏（独立子项目）
EXTRAS_DIR="${REPO_DIR}/extras"     # 附赠配置（Hyprland / Waybar / Kitty / Rofi）
ZSH_DIR="${REPO_DIR}/zsh"           # zsh 配置（oh-my-zsh + 自定义插件）

PREFIX="/usr/local"
MANPREFIX="${PREFIX}/share/man"
XSESSIONS_DIR="/usr/share/xsessions"
AUTOSTART_DIR="${HOME}/.dwm"
RIME_DIR="${HOME}/.local/share/fcitx5/rime"
ENVD_DIR="${HOME}/.config/environment.d"
XPROFILE="${HOME}/.xprofile"
# 系统级电源 / 熄屏策略（dconf，仅 --system-env 时写入）
DCONF_POWER_FILE="/etc/dconf/db/local.d/00-power-settings"
DCONF_PROFILE="/etc/dconf/profile/user"

VERSION="unknown"
[[ -r "${SRC_DIR}/config.mk" ]] \
	&& VERSION="$(sed -n 's/^VERSION[[:space:]]*=[[:space:]]*//p' "${SRC_DIR}/config.mk" | head -n1)"

# 发行版家族，在 preflight 的 detect_distro() 中确定：arch | debian | unknown
DISTRO_FAMILY="unknown"
DISTRO_NAME="unknown"

# ---- 依赖清单：Arch 系（官方仓库） ----
PKGS_BUILD_ARCH=(base-devel libx11 libxinerama libxft freetype2 fontconfig libxrender)
PKGS_RUNTIME_ARCH=(kitty rofi feh picom dunst xss-lock slock)
PKGS_SCRIPT_ARCH=(brightnessctl alsa-utils iproute2 gawk unzip curl xorg-xset)
PKGS_IME_ARCH=(fcitx5-im fcitx5-rime)
PKGS_ZSH_ARCH=(zsh git)
# AUR（安装失败不中断）
PKGS_AUR_RIME_ARCH=(rime-ice-git)
PKGS_AUR_FONT_ARCH=(maplemono-cn)

# ---- 依赖清单：Debian / Ubuntu 系（apt） ----
# 注意：Debian 系没有 fcitx5-im / rime-ice-git / maplemono-cn 这类元包或 AUR 包，
#       输入法拆成多个包，雾凇拼音与字体改为从上游 GitHub 发布包下载。
PKGS_BUILD_DEB=(build-essential libx11-dev libxinerama-dev libxft-dev
	libfreetype6-dev libfontconfig1-dev libxrender-dev)
PKGS_RUNTIME_DEB=(kitty rofi feh picom dunst xss-lock slock)
PKGS_SCRIPT_DEB=(brightnessctl alsa-utils iproute2 gawk unzip curl x11-xserver-utils)
PKGS_IME_DEB=(fcitx5 fcitx5-chinese-addons fcitx5-rime fcitx5-config-qt
	fcitx5-frontend-gtk2 fcitx5-frontend-gtk3 fcitx5-frontend-qt5)
PKGS_ZSH_DEB=(zsh git)

# ---- zsh / oh-my-zsh ----
ZSH_RC="${ZSH_DIR}/zshrc"                # → ~/.zshrc
OMZ_DIR="${HOME}/.oh-my-zsh"
OMZ_PLUGINS_DIR="${OMZ_DIR}/custom/plugins"
# oh-my-zsh 官方地址在国内较慢，默认用清华镜像（可用环境变量覆盖）
OMZ_GIT_URL="${DWM_OMZ_GIT_URL:-https://mirrors.tuna.tsinghua.edu.cn/git/ohmyzsh.git}"
# GitHub 前缀，可直接换成代理前缀，如 https://ghproxy.net/https://github.com
ZSH_GH_MIRROR="${ZSH_GH_MIRROR:-https://github.com}"
# 非 oh-my-zsh 自带的插件，需要单独 clone 到 $ZSH_CUSTOM/plugins/
ZSH_CUSTOM_PLUGINS=(zsh-autosuggestions zsh-syntax-highlighting)

# ---- 上游资源（Debian / Ubuntu 无 AUR，改为直接下载） ----
RIME_ICE_URL="https://github.com/iDvel/rime-ice/releases/download/nightly/full.zip"
MAPLE_FONT_URL="https://github.com/subframe7536/maple-font/releases/latest/download/MapleMono-NF-CN.zip"
FONT_DIR="${HOME}/.local/share/fonts/MapleMono-CN"

# --------------------------------------------------------------------------- #
# 参数
# --------------------------------------------------------------------------- #

DRY_RUN=false
ASSUME_YES=false
WITH_DEPS=true
WITH_DWM=true
WITH_DWMBLOCKS=true
WITH_IME=true
WITH_FONT=true
WITH_EXTRAS=false
WITH_ZSH=true
WITH_CHSH=true
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
      --no-deps            跳过依赖安装（含字体 / 雾凇拼音下载）
      --no-dwm             跳过 dwm 编译安装
      --no-dwmblocks       跳过 dwmblocks 编译安装
      --extras             额外部署 extras/ 到 ~/.config/（Hyprland / Waybar / Kitty / Rofi）
      --no-ime             跳过 fcitx5 / 雾凇拼音配置
      --no-font            跳过 Maple Mono CN 字体安装
      --no-zsh             跳过 zsh 配置（oh-my-zsh + 插件 + ~/.zshrc）
      --no-chsh            部署 zsh 配置，但不改登录 shell
      --system-env         写入系统级配置（需 root，影响全局）：
                           /etc/environment 的输入法环境变量
                           + ${DCONF_POWER_FILE}
                           电源策略（禁止自动挂起、空闲 15 分钟熄屏）
      --prefix DIR         安装前缀（默认 ${PREFIX}）
      --autostart-dir DIR  自启脚本部署目录（默认 ~/.dwm）
      --uninstall          卸载 dwm / dwmblocks / 会话文件 / 自启目录
  -h, --help               显示本帮助

${C_BOLD}发行版支持${C_RESET}
  - Arch 系：pacman + yay/paru（雾凇拼音、Maple Mono CN 走 AUR）
  - Debian / Ubuntu 系：apt，雾凇拼音与字体从上游 GitHub 发布包下载
  - 其它发行版：加 --no-deps 跳过依赖步骤，自行准备编译工具链

${C_BOLD}zsh${C_RESET}
  oh-my-zsh 默认从清华镜像克隆：${OMZ_GIT_URL}
  可用环境变量覆盖：DWM_OMZ_GIT_URL（oh-my-zsh）、ZSH_GH_MIRROR（插件用的 GitHub 前缀）
  已有的 ~/.oh-my-zsh 与插件目录不会被覆盖，~/.zshrc 有差异时先备份再写入

${C_BOLD}示例${C_RESET}
  ./${SCRIPT_NAME} --dry-run          # 先看看会做什么
  ./${SCRIPT_NAME}                    # 完整安装
  ./${SCRIPT_NAME} --no-deps --no-ime # 只编译安装，不动依赖和输入法
  ./${SCRIPT_NAME} --no-zsh           # 不动 zsh 与登录 shell
  ./${SCRIPT_NAME} --system-env       # 额外写入 /etc（输入法环境变量 + 电源策略）
  ./${SCRIPT_NAME} --uninstall        # 卸载

${C_BOLD}安装后${C_RESET}
  注销并重新登录，在登录界面选择 "Dwm" 会话；新登录 shell 生效后可执行 exec zsh 立即切换。
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
			--extras)           WITH_EXTRAS=true ;;
			--no-ime)           WITH_IME=false ;;
			--no-font)          WITH_FONT=false ;;
			--no-zsh)           WITH_ZSH=false ;;
			--no-chsh)          WITH_CHSH=false ;;
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

# 以 root 写入文本文件（幂等 + 自动备份），供 /etc 下的配置使用
write_root_file() {
	local path="$1" content="$2" bak tmp

	tmp="$(mktemp)"
	printf '%s\n' "$content" >"$tmp"

	if [[ $DRY_RUN == false ]] && as_root test -f "$path" && ! as_root cmp -s "$tmp" "$path"; then
		bak="${path}.bak.$(date +%Y%m%d%H%M%S)"
		as_root cp -a -- "$path" "$bak"
		warn "原文件已备份 → ${bak}"
	fi

	if [[ $DRY_RUN == true ]]; then
		printf '%s  [dry-run]%s 写入 %s（root）\n' "$C_CYAN" "$C_RESET" "$path"
	else
		as_root install -Dm644 "$tmp" "$path"
		ok "写入 ${path}"
	fi

	rm -f "$tmp"
}

# --------------------------------------------------------------------------- #
# 步骤 1：环境检查
# --------------------------------------------------------------------------- #

# 探测发行版家族，并据此调整平台相关路径
detect_distro() {
	local id="" like="" info=""

	if [[ -r /etc/os-release ]]; then
		# 在子 shell 中解析：os-release 里的 VERSION 会覆盖本脚本的同名变量
		info="$(. /etc/os-release >/dev/null 2>&1;
			printf '%s|%s|%s' "${ID:-}" "${ID_LIKE:-}" "${PRETTY_NAME:-unknown}")"
		IFS='|' read -r id like DISTRO_NAME <<<"$info"
	fi

	if have pacman && [[ "$id" == "arch" || "$like" == *arch* ]]; then
		DISTRO_FAMILY=arch
	elif have apt-get \
		&& [[ "$id" == "debian" || "$id" == "ubuntu" || "$like" == *debian* || "$like" == *ubuntu* ]]; then
		DISTRO_FAMILY=debian
	elif [[ -z "$DISTRO_NAME" || "$DISTRO_NAME" == "unknown" ]]; then
		# 没有 /etc/os-release 时退化为「按包管理器猜」
		if have pacman; then
			DISTRO_FAMILY=arch
		elif have apt-get; then
			DISTRO_FAMILY=debian
		fi
	fi

	# Debian / Ubuntu 的 X11 会话由 /etc/X11/Xsession 读取 ~/.xsessionrc，
	# 而 Arch 系习惯用 ~/.xprofile（startx / LightDM）。
	if [[ "$DISTRO_FAMILY" == "debian" ]]; then
		XPROFILE="${HOME}/.xsessionrc"
	fi
}

require_build_tools() {
	if [[ $DRY_RUN == true ]]; then
		log "[dry-run] 跳过编译工具检查"
		return 0
	fi

	local missing=()
	have make || missing+=(make)
	{ have cc || have gcc; } || missing+=(cc)

	if [[ ${#missing[@]} -gt 0 ]]; then
		die "缺少编译工具：${missing[*]}（Arch: base-devel；Debian/Ubuntu: build-essential）"
	fi
}

preflight() {
	step "环境检查"

	[[ -f "${SRC_DIR}/dwm.c" && -f "${SRC_DIR}/Makefile" ]] \
		|| die "源码目录不完整：${SRC_DIR}（请在仓库根目录运行本脚本）"

	detect_distro
	log "系统：${DISTRO_NAME}"
	case "$DISTRO_FAMILY" in
		arch)   ok "识别为 Arch 系发行版（pacman + AUR helper）" ;;
		debian) ok "识别为 Debian / Ubuntu 系发行版（apt）" ;;
		*)      warn "未识别的发行版，依赖安装步骤将被跳过（可显式加 --no-deps 消除本提示）" ;;
	esac

	# 工具链缺失时先交给依赖步骤补齐；只有明确跳过依赖安装才立即报错
	if [[ $WITH_DEPS == false ]]; then
		require_build_tools
	else
		local t
		for t in make cc gcc; do
			have "$t" || {
				warn "未找到 ${t}，将由依赖安装步骤补齐"
				break
			}
		done
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

# AUR 安装（Arch 专用）。可选包失败不中断整体安装。
aur_install() {
	local pkgs=("$@") helper args
	helper="$(aur_helper)"
	if [[ -z "$helper" ]]; then
		warn "未找到 yay / paru，跳过 AUR 包：${pkgs[*]}"
		warn "可稍后手动安装，或改用 sudo pacman -S 对应的官方包"
		return 0
	fi

	args=(-S --needed)
	if [[ $ASSUME_YES == true ]]; then
		args+=(--noconfirm)
	elif [[ "$helper" == "yay" ]]; then
		# 避免 yay 交互式询问 cleanBuild / diff
		args+=(--answerclean None --answerdiff None --answeredit None)
	fi

	log "AUR（${helper}）：${pkgs[*]}"
	run "$helper" "${args[@]}" "${pkgs[@]}" \
		|| warn "AUR 包安装失败，可稍后手动执行：${helper} -S ${pkgs[*]}"
}

# 下载工具：优先 curl，回退 wget
download() {
	local url="$1" dest="$2"
	if have curl; then
		run curl -fL --retry 3 --connect-timeout 15 -o "$dest" "$url"
	elif have wget; then
		run wget -q --tries=3 --timeout=15 -O "$dest" "$url"
	else
		warn "未找到 curl / wget，无法下载 ${url}"
		return 1
	fi
}

install_deps_arch() {
	local pacman_args=(-S --needed)
	[[ $ASSUME_YES == true ]] && pacman_args+=(--noconfirm)

	log "pacman：$*"
	as_root pacman "${pacman_args[@]}" "$@"
}

install_deps_deb() {
	if [[ $DRY_RUN == true ]]; then
		printf '%s  [dry-run]%s sudo apt-get update\n' "$C_CYAN" "$C_RESET"
		printf '%s  [dry-run]%s sudo apt-get install -y %s\n' "$C_CYAN" "$C_RESET" "$*"
		return 0
	fi

	# 先刷新索引，否则全新系统上 apt-cache 查不到任何包
	as_root apt-get update

	# 逐个过滤：部分包在旧版 Ubuntu 上不存在，跳过而不是让整批安装失败
	local available=() p
	for p in "$@"; do
		if apt-cache show "$p" >/dev/null 2>&1; then
			available+=("$p")
		else
			warn "软件源中没有该包，已跳过：${p}"
		fi
	done

	if [[ ${#available[@]} -eq 0 ]]; then
		warn "没有可安装的软件包"
		return 0
	fi

	local apt_args=(-y)
	[[ $ASSUME_YES == true ]] && apt_args+=(--assume-yes)

	log "apt：${available[*]}"

	# DEBIAN_FRONTEND 避免 tzdata 等包的交互式提问
	as_root env DEBIAN_FRONTEND=noninteractive \
		apt-get install "${apt_args[@]}" "${available[@]}"
}

# ---- 可选上游资源：雾凇拼音 ----
install_rime_ice() {
	step "配置雾凇拼音（rime-ice）"

	if [[ "$DISTRO_FAMILY" == "arch" ]]; then
		aur_install "${PKGS_AUR_RIME_ARCH[@]}"
		log "提示：rime-ice-git 安装到系统目录，无需再手工下载"
		return 0
	fi

	if [[ -e "${RIME_DIR}/rime_ice.schema.yaml" ]]; then
		ok "雾凇拼音已存在于 ${RIME_DIR}，跳过"
		return 0
	fi

	if ! have unzip; then
		warn "未找到 unzip，跳过雾凇拼音（Arch: sudo pacman -S unzip；Ubuntu: sudo apt install unzip）"
		return 0
	fi

	if [[ $DRY_RUN == true ]]; then
		printf '%s  [dry-run]%s 下载并解压 %s → %s\n' \
			"$C_CYAN" "$C_RESET" "$RIME_ICE_URL" "$RIME_DIR"
		return 0
	fi

	run mkdir -p "${RIME_DIR}"
	local tmp
	tmp="$(mktemp -d)"

	if download "$RIME_ICE_URL" "${tmp}/rime-ice.zip" \
		&& unzip -oq "${tmp}/rime-ice.zip" -d "${RIME_DIR}"; then
		ok "雾凇拼音已部署 → ${RIME_DIR}"
	else
		warn "雾凇拼音下载 / 解压失败，可稍后手动处理：${RIME_ICE_URL}"
	fi

	rm -rf -- "$tmp"
}

# ---- 可选上游资源：Maple Mono CN 字体（Nerd Font，状态栏图标依赖） ----
install_font() {
	step "安装 Maple Mono CN 字体"

	# 注意：不要写成 "fc-list | grep -q"，grep -q 命中后会提前退出，
	# 使 fc-list 收到 SIGPIPE，在 pipefail 下整条管道被判为失败。
	local font_installed=false
	if [[ -d "$FONT_DIR" ]]; then
		font_installed=true
	elif have fc-list; then
		local fonts
		fonts="$(fc-list 2>/dev/null || true)"
		[[ "$fonts" == *"Maple Mono CN"* ]] && font_installed=true
	fi

	if [[ $font_installed == true ]]; then
		ok "系统中已存在 Maple Mono CN，跳过"
		return 0
	fi

	if [[ "$DISTRO_FAMILY" == "arch" ]]; then
		aur_install "${PKGS_AUR_FONT_ARCH[@]}"
		return 0
	fi

	if ! have unzip; then
		warn "未找到 unzip，跳过字体安装（状态栏图标可能显示为方块）"
		return 0
	fi

	if [[ $DRY_RUN == true ]]; then
		printf '%s  [dry-run]%s 下载并解压 %s → %s\n' \
			"$C_CYAN" "$C_RESET" "$MAPLE_FONT_URL" "$FONT_DIR"
		return 0
	fi

	local tmp
	tmp="$(mktemp -d)"

	if download "$MAPLE_FONT_URL" "${tmp}/maple.zip" \
		&& unzip -oq "${tmp}/maple.zip" -d "${tmp}/font"; then
		run mkdir -p "$FONT_DIR"
		find "${tmp}/font" -type f \( -iname '*.ttf' -o -iname '*.otf' \) \
			-exec install -m644 {} "$FONT_DIR"/ \;
		have fc-cache && fc-cache -f "$FONT_DIR" >/dev/null 2>&1
		ok "字体已安装 → ${FONT_DIR}（若状态栏仍乱码可重新登录）"
	else
		warn "字体下载 / 解压失败，状态栏图标可能显示为方块"
		warn "可手动下载后解压到 ${FONT_DIR}：${MAPLE_FONT_URL}"
	fi

	rm -rf -- "$tmp"
}

install_deps() {
	step "安装依赖"

	local pkgs=()
	case "$DISTRO_FAMILY" in
		arch)
			pkgs=("${PKGS_BUILD_ARCH[@]}" "${PKGS_RUNTIME_ARCH[@]}" "${PKGS_SCRIPT_ARCH[@]}")
			[[ $WITH_IME == true ]] && pkgs+=("${PKGS_IME_ARCH[@]}")
			[[ $WITH_ZSH == true ]] && pkgs+=("${PKGS_ZSH_ARCH[@]}")
			install_deps_arch "${pkgs[@]}"
			;;
		debian)
			pkgs=("${PKGS_BUILD_DEB[@]}" "${PKGS_RUNTIME_DEB[@]}" "${PKGS_SCRIPT_DEB[@]}")
			[[ $WITH_IME == true ]] && pkgs+=("${PKGS_IME_DEB[@]}")
			[[ $WITH_ZSH == true ]] && pkgs+=("${PKGS_ZSH_DEB[@]}")
			install_deps_deb "${pkgs[@]}"
			;;
		*)
			warn "未识别的发行版，跳过依赖安装"
			warn "请自行准备：make / C 编译器 / libX11 / libXinerama / libXft / libXrender 开发包"
			return 0
			;;
	esac

	if [[ $WITH_IME == true ]]; then
		install_rime_ice
	else
		log "已指定 --no-ime，跳过 fcitx5 相关包与雾凇拼音"
	fi

	if [[ $WITH_FONT == true ]]; then
		install_font
	else
		log "已指定 --no-font，跳过字体安装"
	fi

	ok "依赖处理完成"
}

# --------------------------------------------------------------------------- #
# 步骤 3：编译安装 dwm / dwmblocks
# --------------------------------------------------------------------------- #

build_dwm() {
	step "编译 dwm ${VERSION}"
	run make -C "${SRC_DIR}" clean
	run make -C "${SRC_DIR}"
	ok "dwm 编译完成"

	step "安装 dwm → ${PREFIX}/bin"
	as_root make -C "${SRC_DIR}" install PREFIX="${PREFIX}" MANPREFIX="${MANPREFIX}"
	ok "dwm 已安装"
}

build_dwmblocks() {
	step "编译 dwmblocks"
	[[ -f "${BLOCKS_DIR}/blocks.h" ]] \
		|| warn "blocks.h 不存在，将使用上游默认模块定义（不影响 dwm 本身）"
	run make -C "${BLOCKS_DIR}" clean
	run make -C "${BLOCKS_DIR}"
	ok "dwmblocks 编译完成"

	step "安装 dwmblocks → ${PREFIX}/bin"
	as_root make -C "${BLOCKS_DIR}" install PREFIX="${PREFIX}"
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
	run sed -i "s|${old_prefix}|${escaped}|g" "${BLOCKS_DIR}/blocks.h"
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

	install_file "${REPO_DIR}/scripts/autostart.sh" "${AUTOSTART_DIR}/autostart.sh" 755
	install_file "${REPO_DIR}/scripts/lock.sh" "${AUTOSTART_DIR}/scripts/lock.sh" 755

	local s
	for s in "${REPO_DIR}"/scripts/statusbar/*.sh; do
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
# 步骤 5.5：附赠配置（可选，--extras）
# --------------------------------------------------------------------------- #

# extras/<name>/ → ~/.config/<name>/
install_extras() {
	step "部署附赠配置（extras/ → ~/.config/）"

	local d name target bak
	for d in "${EXTRAS_DIR}"/*/; do
		[[ -d "$d" ]] || continue
		name="$(basename -- "$d")"
		target="${HOME}/.config/${name}"

		if [[ $DRY_RUN == true ]]; then
			printf '%s  [dry-run]%s 部署 %s → %s\n' "$C_CYAN" "$C_RESET" "${d%/}" "$target"
			continue
		fi

		if [[ -d "$target" ]]; then
			bak="${target}.bak.$(date +%Y%m%d%H%M%S)"
			cp -a -- "$target" "$bak"
			warn "已备份原配置 → ${bak}"
		fi

		mkdir -p "$target"
		cp -a -- "${d}." "$target"/
		ok "部署 ${name} → ${target}"
	done

	ok "附赠配置部署完成（登录界面选择 Hyprland 会话后生效）"
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
# 步骤 7：系统级电源策略（仅 --system-env）
# --------------------------------------------------------------------------- #

# dconf 系统级电源策略：禁止自动挂起 + 空闲 15 分钟熄屏
dconf_power_content() {
	cat <<'EOF'
# 由 dwm/install.sh 生成 —— 电源 / 熄屏策略
# 1) 空闲 15 分钟（900 秒）后关闭屏幕
# 2) 禁止自动挂起（交流与电池都不挂起）
[org/gnome/desktop/session]
idle-delay=uint32 900

[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'
sleep-inactive-battery-type='nothing'
sleep-inactive-ac-timeout=0
sleep-inactive-battery-timeout=0
EOF
}

# dconf 只有在 profile 里声明了 system-db:local 时才会读取 db/local.d/
dconf_profile_content() {
	cat <<'EOF'
user-db:user
system-db:local
EOF
}

# 写入 dconf 系统级电源策略，然后重新编译数据库
# 注意：dconf 只对 GNOME 会话（含 GDM 登录界面）生效；
#       dwm 会话的熄屏由 ~/.dwm/autostart.sh 里的 xset 负责（见 SCREEN_TIMEOUT）。
setup_power_policy() {
	step "写入系统级电源策略（dconf）"

	if [[ ! -d /etc/dconf ]]; then
		warn "未发现 /etc/dconf（系统未安装 dconf），跳过电源策略"
		return 0
	fi

	write_root_file "${DCONF_POWER_FILE}" "$(dconf_power_content)"

	if [[ $DRY_RUN == true ]]; then
		printf '%s  [dry-run]%s 确保 %s 引用 system-db:local\n' \
			"$C_CYAN" "$C_RESET" "${DCONF_PROFILE}"
	elif as_root test -f "${DCONF_PROFILE}"; then
		if as_root grep -qE '^[[:space:]]*system-db:local[[:space:]]*$' "${DCONF_PROFILE}"; then
			log "${DCONF_PROFILE} 已引用 system-db:local"
		else
			as_root cp -a -- "${DCONF_PROFILE}" "${DCONF_PROFILE}.bak.$(date +%Y%m%d%H%M%S)"
			printf '%s\n' 'system-db:local' \
				| as_root tee -a "${DCONF_PROFILE}" >/dev/null
			ok "已向 ${DCONF_PROFILE} 追加 system-db:local"
		fi
	else
		write_root_file "${DCONF_PROFILE}" "$(dconf_profile_content)"
	fi

	if have dconf; then
		as_root dconf update
		ok "dconf 数据库已更新（注销重新登录后生效）"
	else
		warn "未找到 dconf 命令，请手动执行：sudo dconf update"
	fi
}

# --------------------------------------------------------------------------- #
# 步骤 8：zsh（oh-my-zsh + 自定义插件 + ~/.zshrc）
# --------------------------------------------------------------------------- #

# 自定义插件的 clone 地址（前缀可换成 GitHub 代理）
zsh_plugin_url() {
	case "$1" in
		zsh-autosuggestions)     echo "${ZSH_GH_MIRROR}/zsh-users/zsh-autosuggestions" ;;
		zsh-syntax-highlighting) echo "${ZSH_GH_MIRROR}/zsh-users/zsh-syntax-highlighting" ;;
		*)                       echo "" ;;
	esac
}

# 当前登录 shell（从 /etc/passwd 读，$SHELL 在 sudo / 子 shell 里可能不准）
current_login_shell() {
	awk -F: -v u="$(id -un)" '$1 == u { print $7 }' /etc/passwd
}

# 克隆需要 git，缺了就直接失败（--no-deps 时尤其容易碰到）
require_git() {
	if [[ $DRY_RUN == false ]]; then
		have git || die "需要 git 才能克隆 oh-my-zsh（请先安装 git，或加 --no-zsh 跳过本步）"
	fi
}

# 克隆 oh-my-zsh 与自定义插件；已存在的一律跳过（不覆盖、不更新）
install_omz() {
	step "安装 oh-my-zsh"
	log "源：${OMZ_GIT_URL}"

	if [[ -d "${OMZ_DIR}/.git" ]]; then
		ok "已存在 ${OMZ_DIR}，跳过克隆"
	elif [[ -e "$OMZ_DIR" ]]; then
		warn "${OMZ_DIR} 已存在但不是 git 仓库，跳过克隆（如需重装请先备份并删除该目录）"
	else
		require_git
		run git clone --depth=1 "$OMZ_GIT_URL" "$OMZ_DIR"
		ok "oh-my-zsh 已克隆到 ${OMZ_DIR}"
	fi

	local p dst
	for p in "${ZSH_CUSTOM_PLUGINS[@]}"; do
		dst="${OMZ_PLUGINS_DIR}/${p}"
		if [[ -e "$dst" ]]; then
			ok "插件已存在：${p}"
			continue
		fi

		require_git
		run mkdir -p "$OMZ_PLUGINS_DIR"
		run git clone --depth=1 "$(zsh_plugin_url "$p")" "$dst"
		ok "插件已克隆：${p}"
	done
}

# 部署 ~/.zshrc（install_file 会自动备份内容不同的原文件）
deploy_zshrc() {
	step "部署 zsh 配置 → ${HOME}/.zshrc"
	install_file "$ZSH_RC" "${HOME}/.zshrc" 644
	ok "zsh 主配置已就绪（ZSH_THEME / 插件列表见 ~/.zshrc）"
}

# 把登录 shell 改成 zsh
setup_login_shell() {
	local zsh_bin current resolved_zsh resolved_now
	zsh_bin="$(command -v zsh || true)"
	if [[ -z "$zsh_bin" ]]; then
		warn "未找到 zsh 命令，跳过修改登录 shell（可稍后安装 zsh 再执行：chsh -s \$(command -v zsh)）"
		return 0
	fi

	# /bin/zsh 与 /usr/bin/zsh 是同一个东西（usrmerge），比较解析后的真实路径
	current="$(current_login_shell)"
	resolved_zsh="$(readlink -f "$zsh_bin" 2>/dev/null || echo "$zsh_bin")"
	resolved_now="$(readlink -f "${current:-/nonexistent}" 2>/dev/null || echo "${current:-}")"
	if [[ -n "$current" && "$resolved_now" == "$resolved_zsh" ]]; then
		ok "登录 shell 已是 zsh（${current}）"
		return 0
	fi

	if ! grep -qxF "$zsh_bin" /etc/shells 2>/dev/null; then
		warn "${zsh_bin} 不在 /etc/shells 中，chsh 会拒绝执行"
		warn "请手动添加后执行：chsh -s ${zsh_bin}"
		return 0
	fi

	log "登录 shell：${current:-未知} → ${zsh_bin}"
	confirm "把登录 shell 改成 ${zsh_bin}？" || {
		log "已跳过，可稍后手动执行：chsh -s ${zsh_bin}"
		return 0
	}

	as_root chsh -s "$zsh_bin" "$(id -un)" \
		|| die "chsh 失败，请手动执行：chsh -s ${zsh_bin}"
	ok "登录 shell 已改为 zsh（下次登录生效）"
}

setup_zsh() {
	install_omz
	deploy_zshrc
	if [[ $WITH_CHSH == true ]]; then
		setup_login_shell
	else
		log "已指定 --no-chsh，跳过登录 shell 修改"
	fi
	ok "zsh 配置完成"
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
	log "${DCONF_POWER_FILE}（若用过 --system-env 写入过电源策略）"
	log "${DCONF_PROFILE} 中追加的 system-db:local 行（若该文件由本脚本创建，可整个删除）"
	log "${RIME_DIR}/default.custom.yaml（Rime 方案配置）"
	log "${RIME_DIR}/（若由本脚本下载过雾凇拼音，整个目录都是本脚本产生的）"
	log "${FONT_DIR}（若由本脚本下载过 Maple Mono CN 字体）"
	log "~/.config/{hypr,waybar,kitty,rofi}（若用过 --extras）"
	log "${HOME}/.zshrc 与 ${OMZ_DIR}/（zsh 配置；若改过登录 shell，还需手动改回：chsh -s \$(command -v bash)"

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
	if [[ $WITH_DWM == true || $WITH_DWMBLOCKS == true ]]; then
		require_build_tools
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

	# --system-env 的含义是「写入系统级配置」：除输入法环境变量外，还包括电源策略
	if [[ $USE_SYSTEM_ENV == true ]]; then
		setup_power_policy
	fi

	if [[ $WITH_EXTRAS == true ]]; then
		install_extras
	fi

	if [[ $WITH_ZSH == true ]]; then
		setup_zsh
	fi

	step "全部完成"

	# zsh 没装到就不提这一条
	local zsh_hint=""
	if [[ $WITH_ZSH == true ]]; then
		zsh_hint=$'\n  5. zsh 配置已部署：新开终端即为新配置；改了登录 shell 的需重新登录（或 exec zsh）'
	fi

	cat <<EOF

下一步：
  1. 注销并重新登录，在登录界面选择 "Dwm" 会话
     （Ubuntu 的 GDM 登录界面点用户名后，右下角齿轮里选 Dwm）
  2. 首次启动后确认状态栏正常：pkill -RTMIN+11 dwmblocks 可手动刷新音量/亮度
  3. 修改 src/config.h 或 dwmblocks/blocks.h 后需重新执行 ./${SCRIPT_NAME}
     （或手动 make -C src / make -C dwmblocks）
  4. Super + Escape 手动锁屏；空闲 15 分钟自动熄屏并上锁
     （时长见 ~/.dwm/autostart.sh 顶部的 SCREEN_TIMEOUT）${zsh_hint}

EOF

	if [[ $WITH_IME == true && $USE_SYSTEM_ENV == false ]]; then
		log "输入法环境变量写入的是用户级配置，若某些应用仍不生效可尝试：./${SCRIPT_NAME} --system-env"
	fi
	if [[ $USE_SYSTEM_ENV == true ]]; then
		log "电源策略已写入 ${DCONF_POWER_FILE}（对 GNOME 会话生效）"
		log "dwm 会话的熄屏由 autostart.sh 的 SCREEN_TIMEOUT 控制（默认 900 秒）"
	fi
	if [[ $WITH_ZSH == true ]]; then
		log "zsh 配置来自 ${ZSH_RC}，改动后重跑 ./${SCRIPT_NAME} 即可同步到 ~/.zshrc"
	fi
}

main "$@"
