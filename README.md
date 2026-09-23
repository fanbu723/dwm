# dwm — 我的 dwm 桌面配置（Arch Linux / Ubuntu）

基于 [dwm 6.4](https://dwm.suckless.org/) 的个人桌面环境配置，包含窗口管理器源码、状态栏程序、
自启脚本、状态栏脚本，以及一套附赠的 Hyprland / Waybar / Kitty / Rofi 配置。

提供 `install.sh` 一键完成「装依赖 → 编译 → 安装 → 部署脚本（含锁屏 / 熄屏）→ 配置输入法」，
自动识别 **Arch 系** 与 **Debian / Ubuntu 系** 发行版。

![dwm](dwm.png)

---

## 📖 目录

- [✨ 特性](#-特性)
- [📁 目录结构](#-目录结构)
- [📦 依赖](#-依赖)
- [🚀 快速开始](#-快速开始)
- [🔧 手动安装](#-手动安装)
- [🩹 已应用的补丁](#-已应用的补丁)
- [⌨️ 快捷键](#-快捷键)
- [⚙️ 配置说明](#-配置说明)
- [🀄 输入法（fcitx5 + 雾凇拼音）](#-输入法fcitx5--雾凇拼音)
- [🎁 附赠配置（extras/）](#-附赠配置extras)
- [🗑 卸载](#-卸载)
- [❓ 常见问题](#-常见问题)
- [📄 许可](#-许可)

---

## ✨ 特性

- **dwm 6.4** 深度定制：窗口间隙（vanitygaps）、状态栏半透明 + 系统托盘、暂存窗口、
  全屏、每个标签独立记忆布局参数（pertag）
- **dwmblocks** 状态栏：网速 / CPU / 内存 / 音量 / 亮度 / 电量 / 时间
- **自动锁屏**：`xss-lock` 监听空闲 / 熄屏 / 挂起事件自动上锁，锁屏程序自动挑选（`slock` / `i3lock` / `betterlockscreen`）；`Super + Escape` 手动锁屏
- **熄屏 / 挂起策略**：dwm 会话空闲 15 分钟熄屏（`xset` + DPMS，`SCREEN_TIMEOUT` 可调）；`--system-env` 时写入 dconf，禁止自动挂起（GNOME / GDM）
- **一键安装脚本** `install.sh`：幂等、支持 `--dry-run`、支持 `--uninstall`
- **跨发行版**：自动区分 `pacman` / `apt`，Ubuntu 上自动补齐拆分后的 fcitx5 包
- **fcitx5 + 雾凇拼音** 自动配置（含环境变量）
- 附赠 **Hyprland** 完整配置（`extras/`），与 dwm 共存互不影响

---

## 📁 目录结构

按「编译产物 / 运行时脚本 / 文档」分层，根目录只留入口和文档：

```
dwm/
├── src/                      # dwm 本体（上游源码 + 编译配置）
│   ├── dwm.c  drw.c  drw.h  util.c  util.h  transient.c
│   ├── config.h              # ★ dwm 配置（改完需重新编译）
│   ├── config.def.h          # 上游默认配置模板
│   ├── config.mk             # 编译参数（PREFIX / VERSION 等）
│   ├── Makefile
│   └── dwm.1                 # man page
├── dwmblocks/                # 状态栏（独立子项目，自带 Makefile 与 LICENSE）
│   ├── dwmblocks.c
│   ├── blocks.h              # ★ 状态栏模块定义（改完需重新编译）
│   └── blocks.def.h          # 上游默认模块定义
├── scripts/                  # 部署到 ~/.dwm 的运行时脚本
│   ├── autostart.sh          #   → ~/.dwm/autostart.sh
│   ├── lock.sh               #   → ~/.dwm/scripts/lock.sh（锁屏，键位与 xss-lock 共用）
│   └── statusbar/            #   → ~/.dwm/scripts/
│       ├── wlan.sh  cpu.sh  memory.sh  volume.sh
│       └── backlight.sh  battery.sh  date.sh
├── extras/                   # 附赠配置（Hyprland / Waybar / Kitty / Rofi）
├── patches/                  # 补丁存档与说明（见 patches/README.md）
├── dwm.desktop               # XSession 会话文件（安装到 /usr/share/xsessions）
├── dwm.png                   # dwm 图标（README 顶部图片）
├── install.sh                # ★ 唯一安装入口
├── .gitignore                # 忽略编译产物与 install.sh 生成的 *.bak.*
├── LICENSE
└── README.md
```

几条路径规则，改文件前先看一眼：

| 规则 | 说明 |
| --- | --- |
| `src/` 只负责 dwm 本体 | `make -C src`、`sudo make -C src install` |
| 打补丁要进 `src/` | `patch -d src -p1 < patches/xxx.diff`（见 `patches/README.md`） |
| `scripts/statusbar/`、`scripts/lock.sh` → `~/.dwm/scripts/` | `blocks.h` / `config.h` 里写死了 `~/.dwm/scripts/xxx.sh`，目录名即部署目标 |
| `extras/<name>/` → `~/.config/<name>/` | 附赠配置，`install.sh --extras` 才会部署 |
| 安装统一走 `install.sh` | 它是唯一入口，`Makefile` 只管各自编译 |

---

## 📦 依赖

`install.sh` 会按发行版自动选择下面的包名，你也可以对照手动安装。

### 构建依赖

| 用途 | Arch | Debian / Ubuntu |
| --- | --- | --- |
| gcc / make | `base-devel` | `build-essential` |
| X11 基础库（含 Xinerama 多显示器） | `libx11` `libxinerama` `libxrender` | `libx11-dev` `libxinerama-dev` `libxrender-dev` |
| 字体渲染 | `libxft` `freetype2` `fontconfig` | `libxft-dev` `libfreetype6-dev` `libfontconfig1-dev` |

### 运行依赖

| 包 | 用途 | 是否必需 | Debian / Ubuntu |
| --- | --- | --- | --- |
| `kitty` | 终端（`config.h` 中 `termcmd`） | 必需 | 同名 |
| `rofi` | 应用启动器（`Super + r`） | 必需 | 同名 |
| `feh` | 设置壁纸 | `scripts/autostart.sh` | 同名 |
| `picom` | 窗口合成器（透明 / 阴影） | `scripts/autostart.sh` | 同名 |
| `dunst` | 通知守护进程 | `scripts/autostart.sh` | 同名 |
| `xss-lock` | 监听空闲 / DPMS / 挂起事件，触发锁屏 | `scripts/autostart.sh` | 同名 |
| `slock` | 锁屏程序（可换成 `i3lock` / `betterlockscreen`，见「锁屏」） | `scripts/autostart.sh` | 同名 |
| `xorg-xset` | 空闲熄屏 / DPMS（`xset`，见「熄屏 / 挂起策略」） | `scripts/autostart.sh` | `x11-xserver-utils` |
| `fcitx5-im` `fcitx5-rime` | 输入法 | 可选 | `fcitx5` `fcitx5-rime` `fcitx5-chinese-addons` `fcitx5-config-qt` `fcitx5-frontend-*` |
| `rime-ice-git` | 雾凇拼音方案 | 可选 | 无对应包，脚本从 [上游 release](https://github.com/iDvel/rime-ice/releases) 下载 |
| `maplemono-cn` | 界面字体 `Maple Mono CN` | 可选 | 无对应包，脚本从 [上游 release](https://github.com/subframe7536/maple-font/releases) 下载 |
| `brightnessctl` | 屏幕亮度（回退 `xbacklight` → `/sys`） | 可选 | 同名 |
| `alsa-utils` 或 `pipewire-pulse` | 音量（优先 `pactl`，回退 `amixer`） | 可选 | 同名 |
| `iproute2` `awk` | 网速模块 | 可选 | 同名 |
| `unzip` `curl` | 下载 / 解压上游字体与词库 | 可选 | 同名 |

> 依赖缺失不会让 dwm 起不来，只是对应的状态栏模块显示为空。
> Ubuntu 上 `picom`、`kitty`、`brightnessctl` 等包在较老版本（如 20.04）可能不存在，
> 脚本会用 `apt-cache` 逐个过滤，缺哪个就跳过哪个并给出提示，不会中断安装。

---

## 🚀 快速开始

```bash
git clone https://github.com/fanbu723/dwm.git
cd dwm
./install.sh --help      # 查看所有参数
./install.sh --dry-run   # 只打印将要执行的操作，不实际修改
./install.sh             # 实际安装
```

脚本会自动识别发行版：Arch 系走 `pacman` + AUR，Debian / Ubuntu 系走 `apt`。

### 各发行版的注意事项

<details open>
<summary><b>Debian / Ubuntu</b></summary>

* 建议 **Ubuntu 22.04 及以上**（`fcitx5`、`kitty`、`picom` 等包在 22.04 才齐备）。
* 需要 sudo 权限，脚本会用 `sudo` 安装包、写入 `/usr/local/bin` 与 `/usr/share/xsessions`。
* Ubuntu 默认是 **Wayland** 会话，dwm 只能跑在 X11 下：注销后点用户名，
  在右下角**齿轮**里选择 **Dwm**（或 "Ubuntu on Xorg"）再登录。
* 输入法环境变量写入的是 `~/.xsessionrc`（Debian 系 `/etc/X11/Xsession` 会读取它），
  而不是 Arch 常见的 `~/.xprofile`。两者同时存在 `~/.config/environment.d/10-ime.conf`。
* 雾凇拼音与 `Maple Mono CN` 字体没有打包，脚本会从 GitHub release 下载并安装到用户目录：
  * `~/.local/share/fcitx5/rime/`（雾凇拼音）
  * `~/.local/share/fonts/MapleMono-CN/`（字体，装完自动 `fc-cache -f`）

</details>

<details>
<summary><b>Arch Linux</b></summary>

* 需要 `yay` 或 `paru` 才能装 `rime-ice-git` / `maplemono-cn`；没有 AUR helper 时会跳过这两项。
* 其余流程与以前一致。

</details>

<details>
<summary><b>其它发行版</b></summary>

加 `--no-deps` 跳过依赖步骤，自行准备 `make`、C 编译器与 `libX11` / `libXinerama` / `libXft` / `libXrender`
开发包，然后：

```bash
./install.sh --no-deps
```

</details>

安装完成后**注销并重新登录**，在登录界面（GDM / LightDM / SDDM）选择 `Dwm` 会话即可。

### install.sh 参数

| 参数 | 说明 |
| --- | --- |
| `-h, --help` | 显示帮助 |
| `-n, --dry-run` | 只打印命令，不执行 |
| `-y, --yes` | 所有询问自动回答 yes（apt / pacman 全部走非交互） |
| `--no-deps` | 跳过依赖安装（含字体与雾凇拼音下载） |
| `--no-dwm` | 不编译安装 dwm 本体（只装状态栏 / 配置） |
| `--no-dwmblocks` | 不编译安装状态栏 |
| `--no-ime` | 跳过 fcitx5 安装与雾凇拼音配置 |
| `--no-font` | 跳过 `Maple Mono CN` 字体安装 |
| `--extras` | 额外把 `extras/` 部署到 `~/.config/`（Hyprland / Waybar / Kitty / Rofi） |
| `--system-env` | 写入系统级配置（需 root）：`/etc/environment` 的输入法环境变量，以及 `/etc/dconf/db/local.d/00-power-settings` 电源策略 |
| `--prefix DIR` | 安装前缀，默认 `/usr/local` |
| `--autostart-dir DIR` | 自启文件部署目录，默认 `~/.dwm` |
| `--uninstall` | 卸载（二进制、会话文件、`~/.dwm`） |

### 脚本做了什么

1. 检测发行版（Arch 系 / Debian 系 / 其它），选择对应的包管理器与包名
2. 安装缺失依赖；可选依赖（字体、雾凇拼音）失败只告警不中断
   - Debian 系上额外从 GitHub 下载 **雾凇拼音**（`rime-ice`）与 **Maple Mono CN** 字体
3. `make -C src` 编译 dwm → `sudo make -C src install`（默认装到 `/usr/local/bin`）
4. 编译安装 `dwmblocks`
5. 部署 `scripts/autostart.sh` → `~/.dwm/autostart.sh`，
   `scripts/statusbar/*.sh`、`scripts/lock.sh` → `~/.dwm/scripts/`，并补齐可执行权限
6. 安装 `dwm.desktop` 到 `/usr/share/xsessions/`
7. 写入 fcitx5 环境变量（用户级，见下）并生成 `~/.local/share/fcitx5/rime/default.custom.yaml`
8. 检查 `~/.dwm` 与 dwm 实际查找路径是否一致（见 FAQ）

加 `--extras` 时另外把 `extras/<name>/` 复制到 `~/.config/<name>/`（覆盖前自动备份）。
加 `--system-env` 时另外写入系统级电源策略（见「熄屏 / 挂起策略」）。

---

## 🔧 手动安装

<details open>
<summary><b>Arch Linux</b></summary>

```bash
# 1. 依赖
sudo pacman -S --needed base-devel libx11 libxinerama libxft freetype2 fontconfig \
    libxrender kitty rofi feh picom dunst xss-lock slock xorg-xset
yay -S fcitx5-im fcitx5-rime rime-ice-git maplemono-cn

# 2. 编译安装 dwm 与状态栏
make -C src && sudo make -C src install
make -C dwmblocks && sudo make -C dwmblocks install

# 3. 部署自启、锁屏与状态栏脚本
mkdir -p ~/.dwm/scripts
install -m755 scripts/autostart.sh ~/.dwm/autostart.sh
install -m755 scripts/lock.sh ~/.dwm/scripts/lock.sh
install -m755 scripts/statusbar/*.sh ~/.dwm/scripts/

# 4. 会话文件
sudo install -Dm644 dwm.desktop /usr/share/xsessions/dwm.desktop
```

</details>

<details>
<summary><b>Debian / Ubuntu</b></summary>

```bash
# 1. 构建依赖与运行依赖
sudo apt update
sudo apt install -y build-essential libx11-dev libxinerama-dev libxft-dev \
    libfreetype6-dev libfontconfig1-dev libxrender-dev \
    kitty rofi feh picom dunst xss-lock slock brightnessctl alsa-utils iproute2 gawk unzip curl \
    x11-xserver-utils

# 2. 输入法（Ubuntu 上是拆分的多个包）
sudo apt install -y fcitx5 fcitx5-chinese-addons fcitx5-rime fcitx5-config-qt \
    fcitx5-frontend-gtk2 fcitx5-frontend-gtk3 fcitx5-frontend-qt5

# 3. 雾凇拼音（无 deb 包，直接装上游发布包）
mkdir -p ~/.local/share/fcitx5/rime
curl -fL -o /tmp/rime-ice.zip \
    https://github.com/iDvel/rime-ice/releases/download/nightly/full.zip
unzip -oq /tmp/rime-ice.zip -d ~/.local/share/fcitx5/rime

# 4. Maple Mono CN 字体（状态栏图标依赖，同样来自上游发布包）
mkdir -p ~/.local/share/fonts/MapleMono-CN
curl -fL -o /tmp/maple.zip \
    https://github.com/subframe7536/maple-font/releases/latest/download/MapleMono-NF-CN.zip
unzip -oq /tmp/maple.zip -d /tmp/maple-font
find /tmp/maple-font -type f \( -iname '*.ttf' -o -iname '*.otf' \) \
    -exec install -m644 {} ~/.local/share/fonts/MapleMono-CN/ \;
fc-cache -f

# 5. 编译安装 dwm、状态栏、脚本、会话文件
make -C src && sudo make -C src install
make -C dwmblocks && sudo make -C dwmblocks install

mkdir -p ~/.dwm/scripts
install -m755 scripts/autostart.sh ~/.dwm/autostart.sh
install -m755 scripts/lock.sh ~/.dwm/scripts/lock.sh
install -m755 scripts/statusbar/*.sh ~/.dwm/scripts/

sudo install -Dm644 dwm.desktop /usr/share/xsessions/dwm.desktop
```

</details>

---

## 🩹 已应用的补丁

以下补丁已打进 `src/dwm.c`，可在 `dwm.c` / `config.h` 中直接验证：

| 补丁 | 作用 |
| --- | --- |
| `vanitygaps` | 窗口间距（内/外间隙、可调节） |
| `alphasystray` | 状态栏透明 + 系统托盘 |
| `awesomebar` | 状态栏显示窗口标题、窗口隐藏态、点击标题切换窗口 |
| `pertag` | 每个标签页保持各自的布局与参数 |
| `fullscreen` | 全屏（`Super + Shift + f`） |
| `scratchpad` | 临时终端，任意标签页呼出（``Super + ` ``） |
| `rotatestack` | 调整窗口在栈中的顺序 |
| `autostart` | 启动时执行 `~/.dwm/autostart.sh` |

另有 4 个补丁**未应用**（`hide_vacant_tags`、`noborder`、`accessnthmonitor`、`statuscmd`），
它们对使用上的具体影响、以及归档的 diff，见 [`patches/README.md`](patches/README.md)。

---

## ⌨️ 快捷键

`MODKEY` = **Super（Win）**。注意本配置中 `MODKEY|Mod4Mask` 与 `MODKEY` 等价，属于冗余绑定（见 FAQ）。

> 本节按**本仓库的实际配置**（`MODKEY = Super`）书写。
> 上游默认配置用的是 `Mod1`（Alt），两者的差异见文末「与上游默认键位对照」。
> 各键位的图解说明可参考 [Dave's Visual Guide to dwm](https://ratfactor.com/dwm)
> （该文基于默认 Alt 键位）。

### 启动 / 基础

| 快捷键 | 功能 |
| --- | --- |
| `Super + q` | 打开终端 kitty |
| `Super + r` | 应用启动器 rofi（`rofi -show drun`） |
| ``Super + ` `` | 呼出 / 隐藏暂存终端 scratchpad |
| `Super + Escape` | 锁屏（`~/.dwm/scripts/lock.sh`，自动挑 slock / i3lock / betterlockscreen） |
| `Super + b` | 显示 / 隐藏状态栏 |
| `Super + Enter` | 窗口在主区 / 栈区之间切换（zoom） |
| `Super + Tab` | 切回上一个视图 |
| `Super + Shift + c` | 关闭当前窗口 |
| `Super + Shift + q` | 退出 dwm |

### 音量 / 亮度

| 快捷键 | 功能 |
| --- | --- |
| `XF86 音量+` / `音量−` | 音量 ±5%（`pactl`，回退 `amixer`） |
| `XF86 静音` | 切换静音 |
| `XF86 亮度+` / `亮度−` | 亮度 ±5%（`brightnessctl`，回退 `xbacklight`） |
| `Super + =` / `Super + -` | 音量 ±5%（键盘没有多媒体键时的替代绑定） |

> 这些绑定末尾都附带 `pkill -RTMIN+11 dwmblocks`：音量与亮度在 `blocks.h` 中
> `interval = 0`，不发信号状态栏不会刷新，详见「状态栏信号」。

### 布局

| 快捷键 | 功能 |
| --- | --- |
| `Super + t` | 平铺 `[]=` |
| `Super + f` | 浮动 `><>` |
| `Super + m` | 单窗口 `[M]` |
| `Super + Space` | 循环切换布局 |
| `Super + Shift + Space` | 切换当前窗口浮动 |
| `Super + Shift + f` | 全屏 |

平铺布局把屏幕分成两块：左侧的**主区（master）**和右侧的**栈区（stack）**。
新窗口进入主区，原有窗口依次被挤到栈区。

### 窗口与主区

| 快捷键 | 功能 |
| --- | --- |
| `Super + j` / `k` | 焦点移到下一个 / 上一个窗口（平铺下按顺时针 / 逆时针） |
| `Super + Shift + j` / `k` | 调整窗口在栈中的顺序 |
| `Super + i` / `d` | 主区窗口数 +1 / −1（窗口在主区与栈区之间自动流转） |
| `Super + h` / `l` | 主区宽度 −5% / +5% |

### 间隙

| 快捷键 | 功能 |
| --- | --- |
| `Super + y` / `o` | 内间隙（水平）+1 / −1 |
| `Super + Ctrl + y` / `o` | 内间隙（垂直）+1 / −1 |
| `Super + Shift + y` / `o` | 外间隙（垂直）+1 / −1 |
| `Super + Ctrl + h` / `l` | 内间隙（整体）+1 / −1 |
| `Super + Shift + h` / `l` | 外间隙（整体）+1 / −1 |
| `Super + 0` | 开关间隙 |
| `Super + Shift + 0` | 恢复默认间隙 |

> 表中都是**实际生效**的绑定。`config.h` 里还有一组 `Super + Mod4 + y/o`（外间隙水平）与
> `Super + Mod4 + h/l`（内间隙整体），因为 `MODKEY|Mod4Mask` 在 `MODKEY = Mod4Mask` 时
> 等于 `MODKEY`，被更靠前的 `setmfact` / `incrihgaps` 遮蔽而失效，详见 FAQ。
> 因此**外间隙（水平）目前没有可用快捷键**，只能整体调整（`Super + Shift + h/l`）。

### 标签（桌面）

标签（tag）类似虚拟桌面，但比虚拟桌面灵活：**一个窗口可以同时属于多个标签**，
也可以一次查看所有标签的窗口。

| 快捷键 | 功能 |
| --- | --- |
| `Super + 1..9` | 切换到标签 1..9 |
| `Super + Ctrl + 1..9` | 在当前标签上追加 / 移除标签 n |
| `Super + Shift + 1..9` | 把当前窗口移动到标签 n |
| `Super + Ctrl + Shift + 1..9` | 切换当前窗口的标签 n |

> `Super + Ctrl + 1..9` 只有在「一次查看多个标签」时才有意义：
> 它把某个标签的所有窗口从当前视图中加进来或移出去。
> `Super + Tab` 则在当前视图与上一个视图之间来回切换。
> 上游默认的 `Alt + 0`（查看全部标签）和 `Alt + Shift + 0`（把窗口放到全部标签）
> 在本配置中被间隙功能占用，见 FAQ。

### 多显示器

| 快捷键 | 功能 |
| --- | --- |
| `Super + ,` / `.` | 聚焦上 / 下一个显示器 |
| `Super + Shift + ,` / `.` | 把当前窗口移到上 / 下一个显示器 |

> 只有两台显示器时，`上 / 下` 记住其中一个方向就够了；三个以上才有必要两个都记。

### 鼠标

| 操作 | 功能 |
| --- | --- |
| `Super + 左键拖动` | 移动窗口 |
| `Super + 中键` | 切换浮动 / 平铺 |
| `Super + 右键拖动` | 缩放窗口 |
| 左键 / 右键点击标签 | 查看 / 切换查看该标签 |
| `Super + 左键 / 右键点击标签` | 移动窗口到 / 切换窗口的该标签 |
| 左键 / 右键点击布局符号 | 切换布局 / 切到单窗口 |
| 左键点击窗口标题 | 切换到上一个窗口 |
| 中键点击窗口标题 | 放大为主窗口 |
| 中键点击状态栏 | 打开终端 |

> `Super + 左键拖动` 拖动平铺窗口时会自动让它浮动（其余窗口仍保持平铺）；
> `Super + 中键` 只切换**当前窗口**的浮动状态，不改变整体布局。

### 与上游默认键位对照

上游 dwm 默认使用 `Mod1`（Alt），本配置改用 `Super` 并调整了部分绑定。
下表左列是常见操作，方便从其他 dwm 配置迁移过来：

| 操作 | 上游默认 | 本配置 |
| --- | --- | --- |
| 打开终端 | `Alt + Shift + Enter`（st） | `Super + q`（kitty） |
| 应用启动器 | `Alt + p`（dmenu） | `Super + r`（rofi） |
| 暂存终端 | — | ``Super + ` `` |
| 锁屏 | — 上游没有 | `Super + Escape`（调 `~/.dwm/scripts/lock.sh`） |
| 平铺 / 浮动 / 单窗口布局 | `Alt + t` / `f` / `m` | 同上游 |
| 循环布局 | `Alt + Space` | 同上游 |
| 切换当前窗口浮动 | `Alt + Shift + Space` | 同上游 |
| 焦点下一个 / 上一个窗口 | `Alt + j` / `k` | 同上游 |
| 主区窗口数 +1 / −1 | `Alt + i` / `d` | 同上游 |
| 主区宽度 +5% / −5% | `Alt + l` / `h` | 同上游 |
| 窗口在主区 / 栈区间切换（zoom） | `Alt + Enter` | 同上游 |
| 关闭窗口 | `Alt + Shift + c` | 同上游 |
| 退出 dwm | `Alt + Shift + q` | 同上游 |
| 显示 / 隐藏状态栏 | `Alt + b` | 同上游 |
| 查看标签 1..9 | `Alt + 1..9` | 同上游（Alt → Super） |
| 把窗口移到标签 n | `Alt + Shift + 1..9` | 同上游（Alt → Super） |
| 追加 / 移除标签 n | `Alt + Ctrl + 1..9` | 同上游（Alt → Super） |
| 切换当前窗口的标签 n | `Alt + Ctrl + Shift + 1..9` | 同上游（Alt → Super） |
| 当前视图 ↔ 上一个视图 | `Alt + Tab` | 同上游（Alt → Super） |
| 查看全部标签 | `Alt + 0` | ❌ 被 `Super + 0`（间隙开关）占用 |
| 把窗口放到全部标签 | `Alt + Shift + 0` | ❌ 被 `Super + Shift + 0`（恢复默认间隙）占用 |
| 聚焦上 / 下一个显示器 | `Alt + ,` / `.` | 同上游（Alt → Super） |
| 把窗口送到上 / 下一个显示器 | `Alt + Shift + ,` / `.` | 同上游（Alt → Super） |
| 鼠标移动 / 切换浮动 / 缩放窗口 | `Alt + 左键 / 中键 / 右键` | 同上游（Alt → Super） |
| 窗口间距（vanitygaps） | — 上游没有 | `Super + y/o`、`Super + Ctrl/Shift + y/o`、`Super + Ctrl/Shift + h/l` |
| 调整栈内顺序（rotatestack） | — 上游没有 | `Super + Shift + j` / `k` |
| 窗口全屏（fullscreen） | — 上游没有 | `Super + Shift + f` |
| 音量 / 亮度 | — 上游没有 | `XF86` 多媒体键，或 `Super + =` / `-` |

---

## ⚙️ 配置说明

### config.h

改完必须重新编译：`make -C src && sudo make -C src install`（或直接 `./install.sh`）。

| 变量 | 当前值 | 说明 |
| --- | --- | --- |
| `MODKEY` | `Mod4Mask` | 主修饰键 = Super |
| `fonts` | `Maple Mono CN:style=Bold:size=12` | 状态栏字体（缺失会导致方块乱码） |
| `gappih` / `gappiv` / `gappoh` / `gappov` | `10` | 默认间隙 |
| `baralpha` | `0xd0` | 状态栏透明度 |
| `borderpx` | `1` | 窗口边框宽度 |
| `showsystray` | `1` | 显示系统托盘 |
| `tags` | `1..9` | 标签名 |
| `termcmd` | `kitty` | 终端命令 |
| `roficmd` | `rofi -show drun` | 启动器命令 |
| `LOCK_CMD` | `{XDG_DATA_HOME}/dwm/scripts/lock.sh`（回退 `~/.dwm/scripts/lock.sh`） | 锁屏（`Super + Escape`），锁屏程序由脚本内部挑选 |

### blocks.h 与状态栏信号

| 模块 | 脚本 | 间隔(秒) | 信号 |
| --- | --- | --- | --- |
| 网速 | `scripts/statusbar/wlan.sh` | 1 | — |
| CPU | `scripts/statusbar/cpu.sh` | 5 | — |
| 内存 | `scripts/statusbar/memory.sh` | 3 | — |
| 音量 | `scripts/statusbar/volume.sh` | 0 | **11** |
| 亮度 | `scripts/statusbar/backlight.sh` | 0 | **11** |
| 电量 | `scripts/statusbar/battery.sh` | 2 | — |
| 时间 | `scripts/statusbar/date.sh` | 1 | — |

> 上表是**仓库内**的路径；部署后都在 `~/.dwm/scripts/`（`blocks.h` 里写死的就是后者）。
> 模块之间用 `delim` 分隔，当前为 `" | "`。

> **间隔为 0 的模块只在收到信号时刷新**，也就是音量和亮度。
> 调整音量 / 亮度后需要通知 dwmblocks 刷新：
>
> ```bash
> pkill -RTMIN+11 dwmblocks
> ```
>
> 本配置已在 `config.h` 中把音量 / 亮度绑定到 `XF86` 多媒体键（备用 `Super + =` / `-`），
> 并在每次调节后自动发送该信号，见「音量 / 亮度」。
> 若你新增了 `interval = 0` 的模块，记得同步处理。

### autostart.sh

dwm 启动后会依次执行（见 `dwm.c` 的 `runautostart()`）：

1. `~/.dwm/autostart_blocking.sh`（阻塞执行，本仓库没有此文件，可自行创建）
2. `~/.dwm/autostart.sh`（后台执行）

查找路径顺序：`$XDG_DATA_HOME/dwm` → `~/.local/share/dwm` → `~/.dwm`（**只要前一个目录存在就用它**）。

### 锁屏（xss-lock + slock）

X11 本身不会「空闲一段时间就锁屏」，dwm 也不带锁屏功能。
标准做法是让 **xss-lock** 监听空闲 / DPMS / 挂起事件，事件到来时调用锁屏程序
（`scripts/autostart.sh` 已内置这段逻辑）：

```bash
sudo apt install xss-lock slock      # Debian / Ubuntu
sudo pacman -S xss-lock slock        # Arch
```

`~/.dwm/autostart.sh` 启动时会：

1. 按 `betterlockscreen` → `i3lock` → `slock` 的顺序，挑一个**已安装**的锁屏程序
2. 拉起 `xss-lock -- <锁屏程序>` 常驻，空闲 / 熄屏 / 挂起前自动锁屏

想用更好看的锁屏（`i3lock` / `betterlockscreen`），装好即可 —— 脚本会自动优先选到它；
也可以显式指定，带参数也没问题：

```bash
# 写进 ~/.xprofile / ~/.xsessionrc（对所有会话生效）
export LOCKER="betterlockscreen -l"
export LOCKER="i3lock -n -c 222222"
```

> `slock` 校验的是当前用户的登录密码，**必须先设置密码**（`passwd`），否则锁屏后敲一下就能解开。

**手动锁屏**：`Super + Escape`，或直接执行 `~/.dwm/scripts/lock.sh`。
键位与 `xss-lock` 调用的是**同一个脚本**，锁屏程序的挑选逻辑只写在它里面：

```bash
~/.dwm/scripts/lock.sh                  # 自动挑：LOCKER → betterlockscreen → i3lock → slock
LOCKER="slock -v" ~/.dwm/scripts/lock.sh
```

> 键位里的路径按 dwm 自己的查找顺序定位（`$XDG_DATA_HOME/dwm` → `~/.local/share/dwm` → `~/.dwm`，
> 见 `src/config.h` 的 `LOCK_CMD`）；用 `--autostart-dir` 装到别处时记得同步改这一行。
> 锁屏时机（多久算空闲、多久后 DPMS 熄屏）由 X 的空闲计时器决定，
> `xss-lock` 只负责「事件来了就调锁屏」，计时本身见下一节。

### 熄屏 / 挂起策略

「多久关屏」「会不会自动挂起」按会话类型分两层设置，互不干扰：

| 层 | 作用范围 | 由谁设置 |
| --- | --- | --- |
| X（`xset`） | **dwm 会话** | `scripts/autostart.sh`（默认生效） |
| dconf | GNOME 会话、GDM 登录界面 | `./install.sh --system-env` |

**dwm 会话**：`~/.dwm/autostart.sh` 启动时会设置

```bash
xset s 900 900             # 空闲 15 分钟（900 秒）黑屏
xset +dpms dpms 0 0 900    # 紧接着 DPMS 关屏（不走 standby / suspend）
```

关屏的同时会触发 `xss-lock` 锁屏（见上一节）。想改时长或彻底关掉：

```bash
export SCREEN_TIMEOUT=1800   # 空闲 30 分钟熄屏
export SCREEN_TIMEOUT=0      # 永不自动熄屏（等价 xset s off; xset -dpms）
```

写进 `~/.xprofile`（Arch）/ `~/.xsessionrc`（Debian / Ubuntu）即可全局生效。

**GNOME / GDM（需 `--system-env`）**：写入 `/etc/dconf/db/local.d/00-power-settings`

```ini
# 空闲 15 分钟后关闭屏幕
[org/gnome/desktop/session]
idle-delay=uint32 900

# 禁止自动挂起（交流与电池都不挂起）
[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'
sleep-inactive-battery-type='nothing'
sleep-inactive-ac-timeout=0
sleep-inactive-battery-timeout=0
```

```bash
./install.sh --system-env   # 写入策略 + dconf update（脚本内部自己用 sudo）
```

脚本还会确保 `/etc/dconf/profile/user` 里声明了 `system-db:local`
（没有这行 dconf 根本不会读 `local.d/`），最后执行 `dconf update` 编译数据库；
**注销重新登录后生效**。

> **两层都要，原因**：`dwm` 是纯 X11 会话，根本不读 dconf；
> 所以 dconf 那份管的是 GDM 登录界面与 GNOME 会话，`xset` 那份管 dwm 自己。
> 机器不会自动挂起后也别担心忘记锁屏——熄屏时 `xss-lock` 会照常锁上。

### 字符字体

状态栏图标依赖 Nerd Font 字形，本配置使用 `Maple Mono CN`：

```bash
# Arch
yay -S maplemono-cn

# Debian / Ubuntu：装到用户字体目录
mkdir -p ~/.local/share/fonts/MapleMono-CN
curl -fL -o /tmp/maple.zip \
    https://github.com/subframe7536/maple-font/releases/latest/download/MapleMono-NF-CN.zip
unzip -oq /tmp/maple.zip -d /tmp/maple-font
find /tmp/maple-font -type f \( -iname '*.ttf' -o -iname '*.otf' \) \
    -exec install -m644 {} ~/.local/share/fonts/MapleMono-CN/ \;
fc-cache -f
```

`./install.sh` 会自动完成以上步骤（`--no-font` 可跳过，`--no-deps` 会一起跳过）。

---

## 🀄 输入法（fcitx5 + 雾凇拼音）

`install.sh` 默认会：

1. 安装 fcitx5；雾凇拼音方案在 Arch 上来自 AUR（`rime-ice-git`），
   在 Debian / Ubuntu 上从 [上游 release](https://github.com/iDvel/rime-ice/releases) 下载并解压到
   `~/.local/share/fcitx5/rime/`（`--no-ime` 可整段跳过）
2. 写入 `~/.local/share/fcitx5/rime/default.custom.yaml`（已存在则先备份）
3. 写入用户级环境变量，X11 与 Wayland 会话都能生效：

```bash
# ~/.config/environment.d/10-ime.conf   （systemd 图形会话，两个发行版都会写）
# ~/.xprofile                            （Arch：startx / LightDM 等 X11 会话）
# ~/.xsessionrc                          （Debian / Ubuntu：/etc/X11/Xsession 会读取）
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus
```

> `GLFW_IM_MODULE=ibus` 不是笔误：GLFW 只实现了 ibus 协议，fcitx 官方文档即如此要求。
> 加 `--system-env` 才会写入 `/etc/environment`（用 `sudo tee -a` 追加，需重新登录才生效）。

改完别忘了重启 fcitx5 或重新部署 Rime（右键托盘图标 → 重新部署）。

---

## 🎁 附赠配置（extras/）

`extras/` 里是另一套桌面环境 —— **Hyprland** —— 的配置，与 dwm **完全独立**：
不装它 dwm 照常工作，装了也只是多一个可选的登录会话，两者可以自由切换。

| 仓库路径 | 部署目标 | 内容 |
| --- | --- | --- |
| `extras/hypr/` | `~/.config/hypr/` | `hyprland.conf`（主配置）、`hyprpaper.conf`（壁纸） |
| `extras/waybar/` | `~/.config/waybar/` | 状态栏 `config.jsonc` / `style.css` / `scripts/waybar-wttr.py` |
| `extras/kitty/` | `~/.config/kitty/` | 终端配置（dwm 与 Hyprland 共用） |
| `extras/rofi/` | `~/.config/rofi/` | 启动器主题（同样共用） |

部署方式二选一：

```bash
# 方式一：跟着主流程一起装（推荐，覆盖前自动备份）
./install.sh --extras

# 方式二：手动复制
for d in hypr waybar kitty rofi; do
    mkdir -p ~/.config/"$d"
    cp -r extras/"$d"/. ~/.config/"$d"/
done
```

> `kitty` 与 `rofi` 两套配置对 dwm 和 Hyprland 都生效，改一处两边都变。
> Hyprland 的输入法沿用同一套 fcitx5 配置，`install.sh` 写入的环境变量
> （`~/.config/environment.d/10-ime.conf`、`~/.xprofile`）对两者都有效。

---

## 🗑 卸载

```bash
./install.sh --uninstall
```

会删除：`/usr/local/bin/dwm`、`/usr/local/bin/dwmblocks`、
`/usr/share/xsessions/dwm.desktop`、`~/.dwm`。
不会删除：输入法配置、字体、以及你自行修改过的 `~/.config`。

下面这些由安装过程产生、但脚本不会自动删除，会打印出来让你自行确认：

| 路径 | 何时产生 |
| --- | --- |
| `~/.config/environment.d/10-ime.conf` | 安装输入法时 |
| `~/.xprofile` / `~/.xsessionrc` 中标记之间的内容 | 安装输入法时 |
| `~/.local/share/fcitx5/rime/` | Debian / Ubuntu 上下载雾凇拼音时 |
| `~/.local/share/fonts/MapleMono-CN/` | Debian / Ubuntu 上下载字体时 |
| `~/.config/{hypr,waybar,kitty,rofi}` | 用过 `--extras` 时 |
| `/etc/dconf/db/local.d/00-power-settings` | 用过 `--system-env` 时（另需检查 `/etc/dconf/profile/user` 里追加的 `system-db:local`） |

---

## ❓ 常见问题

**Q：状态栏的音量 / 亮度一直空白？**
它们的 `interval` 为 0，只在收到信号时刷新。用上文「音量 / 亮度」里的快捷键调节会自动刷新；
手动改音量（如直接敲 `amixer` / `pactl`）后需要补一条 `pkill -RTMIN+11 dwmblocks`。

**Q：键盘上没有 XF86 多媒体键，怎么调音量？**
用 `Super + =` / `Super + -`；也可以在 `config.h` 里把 `XF86XK_*` 换成自己喜欢的键位后重新编译。

**Q：`Super + 0` 想用来「查看全部标签」，但实际是切换间隙？**
`Super + 0` 与 `Super + Shift + 0` 都被间隙功能占用（`togglegaps` / `defaultgaps` 在
`keys[]` 数组里更靠前，优先匹配），因此上游默认的 `view ~0`（查看全部标签）与
`tag ~0`（把窗口放到全部标签）在本配置中失效。
想用回原来的功能，把 `config.h` 里靠前的那两条注释掉再重新编译即可，
详见「与上游默认键位对照」。

**Q：`Super + h` 不调整间隙？`config.h` 里有些绑定看着有、实际按了没反应？**
根因是 `MODKEY|Mod4Mask` 在本配置（`MODKEY = Mod4Mask`）中**等价于 `MODKEY`**，
于是两条“不同修饰键”的绑定其实争抢同一个键位，`keys[]` 里靠前的那条胜出。
受影响的组合：

| 绑定 | 被谁遮蔽 | 结果 |
| --- | --- | --- |
| `Super + h` / `l` | 靠前的 `setmfact` | 变成调整主区宽度，间隙请用 `Super + Ctrl + h/l`、`Super + Shift + h/l` |
| `Super + y` / `o` | 靠前的 `incrihgaps` | 变成内间隙（水平），外间隙（水平）暂时无快捷键 |
| `Super + 0` | 靠前的 `togglegaps` | 变成开关间隙，见上一条 |

想恢复某个功能，把 `config.h` 里更靠前的那条注释掉再重新编译即可。

**Q：开机进了 dwm 但没有壁纸 / 输入法 / 状态栏？**
1. 确认 `~/.dwm/autostart.sh` 存在且**可执行**（`chmod +x`）
2. 确认 `~/.local/share/dwm` **不存在**，否则 dwm 会用那个目录而忽略 `~/.dwm`
3. 单独运行 `sh -x ~/.dwm/autostart.sh` 看报错

**Q：明明写了 dconf 电源策略，dwm 里屏幕还是照旧？**
`dconf` 只被 GNOME 会话读取，dwm 是纯 X11 会话，看的是 `scripts/autostart.sh` 里的
`xset`（用 `SCREEN_TIMEOUT` 调）。dconf 那份管的是 GDM 登录界面与 GNOME 会话，
两层都要设，详见「熄屏 / 挂起策略」。

**Q：人离开一会儿不会自动锁屏？挂起回来还是桌面？**
1. 确认 `xss-lock` 与锁屏程序都在（`command -v xss-lock slock`）
2. 确认 `xss-lock` 在跑（`pgrep -x xss-lock`），没在跑就看 `sh -x ~/.dwm/autostart.sh` 的报错
3. `slock` 需要该用户**有登录密码**，否则锁不住（见「锁屏」）
4. 触发时机由 X 的空闲 / DPMS 计时决定，`xss-lock` 只负责在事件到来时调锁屏程序

**Q：fcitx5 在 kitty / GTK 应用里打不出中文？**
检查环境变量是否生效（`env | grep IM_MODULE`）、`fcitx5-gtk`/`fcitx5-qt` 是否安装，
以及是否重新登录过。

**Q：状态栏图标显示成方块？**
缺少 `Maple Mono CN` 字体或该字体不含对应 Nerd Font 字形。
Debian / Ubuntu 上可用 `fc-list | grep -i 'Maple Mono CN'` 确认字体是否装上。

**Q：改了 `config.h` / `blocks.h` 之后要做什么？**
两者都是编译期配置：dwm 需 `make -C src && sudo make -C src install`，
状态栏需 `make -C dwmblocks && sudo make -C dwmblocks install`（或直接 `./install.sh`），
然后重新登录。

**Q：Ubuntu 上 `./install.sh` 提示「未识别的发行版」？**
脚本靠 `/etc/os-release` 里的 `ID` / `ID_LIKE` 加包管理器判断。若被裁剪过，
用 `--no-deps` 跳过依赖步骤，手动装好编译工具链后再跑一次。

**Q：Ubuntu 上某些包提示「软件源中没有该包，已跳过」？**
老版本 Ubuntu（如 20.04）没有 `fcitx5` / `kitty` / `picom` 等包。
脚本会跳过缺失项并继续，其余功能（dwm 本体、状态栏）不受影响。
需要这些功能就升级到 22.04+ 或自行加 PPA。

**Q：Ubuntu 登录界面看不到 Dwm 会话？**
1. 确认 `/usr/share/xsessions/dwm.desktop` 存在（`./install.sh` 会装）
2. GDM 登录界面：点用户名后，右下角齿轮里选 **Dwm**
3. 确认当前不是纯 Wayland 会话（dwm 是 X11 窗口管理器，不会出现在纯 Wayland 的会话列表里）

**Q：Ubuntu 上输入法环境变量写在哪个文件？**
Debian 系的 `/etc/X11/Xsession` 读取的是 `~/.xsessionrc`（不是 `~/.xprofile`），
`install.sh` 已自动按发行版选择，另外还会写 `~/.config/environment.d/10-ime.conf`。

**Q：Ubuntu 上雾凇拼音 / 字体下载失败？**
需要能访问 GitHub。可稍后手动下载安装，参见「字符字体」与「输入法」两节，
或用 `--no-ime` / `--no-font` 先跳过。

---

## 📄 许可

- `dwm`、`dwmblocks` 上游代码遵循 MIT / 见各自 `LICENSE`
- 本仓库的配置与脚本部分可自由使用
