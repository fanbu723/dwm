# dwm — 我的 Arch Linux 桌面配置

基于 [dwm 6.4](https://dwm.suckless.org/) 的个人桌面环境配置，包含窗口管理器源码、状态栏程序、
自启脚本、状态栏脚本，以及一套附赠的 Hyprland / Waybar / Kitty / Rofi 配置。

提供 `install.sh` 一键完成「装依赖 → 编译 → 安装 → 部署配置 → 配置输入法」。

![预览](dwm.png)

---

## ✨ 特性

- **dwm 6.4** 深度定制：圆角间距、托盘透明、暂存窗口、全屏、独立桌面布局记忆
- **dwmblocks** 状态栏：网速 / CPU / 内存 / 音量 / 亮度 / 电量 / 时间
- **一键安装脚本** `install.sh`：幂等、支持 `--dry-run`、支持 `--uninstall`
- **fcitx5 + 雾凇拼音** 自动配置（含环境变量）
- 附赠 **Hyprland** 完整配置（`config/`），与 dwm 可共存

---

## 📁 目录结构

```
dwm/
├── dwm.c drw.c util.c        # dwm 源码（已打补丁）
├── config.h                  # ★ dwm 配置（改完需重新编译）
├── config.def.h              # 上游默认配置模板
├── config.mk                 # 编译参数（PREFIX / VERSION 等）
├── Makefile
├── dwm.desktop               # XSession 会话文件（安装到 /usr/share/xsessions）
├── autostart.sh              # ★ dwm 启动后自动执行的脚本
├── scripts/                  # ★ 状态栏脚本（部署到 ~/.dwm/scripts）
│   ├── wlan.sh  cpu.sh  memory.sh  volume.sh
│   └── backlight.sh  battery.sh  date.sh
├── dwmblocks/                # 状态栏程序
│   ├── dwmblocks.c
│   ├── blocks.h              # ★ 状态栏模块定义（改完需重新编译）
│   └── blocks.def.h          # 上游默认模块定义
├── patches/                  # 补丁存档与说明
├── config/                   # 附赠配置（Hyprland / Waybar / Kitty / Rofi）
└── install.sh                # ★ 一键安装脚本
```

路径规则：`blocks.h` 中写死了 `~/.dwm/scripts/xxx.sh`，因此脚本必须部署到 `~/.dwm/scripts/`。

---

## 📦 依赖

### 构建依赖

| 包 | 用途 |
| --- | --- |
| `base-devel` | gcc / make |
| `libx11` `libxinerama` `libxrender` | X11 基础库（Xinerama 多显示器） |
| `libxft` `freetype2` `fontconfig` | 字体渲染 |

### 运行依赖

| 包 | 用途 | 是否必需 |
| --- | --- | --- |
| `kitty` | 终端（`config.h` 中 `termcmd`） | 必需 |
| `rofi` | 应用启动器（`Super + r`） | 必需 |
| `feh` | 设置壁纸 | `autostart.sh` |
| `picom` | 窗口合成器（透明 / 阴影） | `autostart.sh` |
| `dunst` | 通知守护进程 | `autostart.sh` |
| `fcitx5-im` `fcitx5-rime` | 输入法 | 可选 |
| `rime-ice-git`（AUR） | 雾凇拼音方案 | 可选 |
| `maplemono-cn`（AUR） | 界面字体 `Maple Mono CN` | 可选 |
| `brightnessctl` | 屏幕亮度（回退 `xbacklight` → `/sys`） | 可选 |
| `alsa-utils` 或 `pipewire-pulse` | 音量（优先 `pactl`，回退 `amixer`） | 可选 |
| `iproute2` `awk` | 网速模块 | 可选 |

> 依赖缺失不会让 dwm 起不来，只是对应的状态栏模块显示为空。

---

## 🚀 快速开始

```bash
git clone https://github.com/fanbu723/dwm.git
cd dwm
./install.sh --help      # 查看所有参数
./install.sh --dry-run   # 只打印将要执行的操作，不实际修改
./install.sh             # 实际安装
```

安装完成后**注销并重新登录**，在登录界面（LightDM 等）选择 `Dwm` 会话即可。

### install.sh 参数

| 参数 | 说明 |
| --- | --- |
| `-h, --help` | 显示帮助 |
| `-n, --dry-run` | 只打印命令，不执行 |
| `-y, --yes` | 所有询问自动回答 yes |
| `--no-deps` | 跳过依赖安装 |
| `--no-ime` | 跳过 fcitx5 / 雾凇拼音配置 |
| `--no-dwmblocks` | 不编译安装状态栏 |
| `--system-env` | 把输入法环境变量写入 `/etc/environment`（需 root，影响全局） |
| `--prefix DIR` | 安装前缀，默认 `/usr/local` |
| `--autostart-dir DIR` | 自启文件部署目录，默认 `~/.dwm` |
| `--uninstall` | 卸载（二进制、会话文件、`~/.dwm`） |

### 脚本做了什么

1. 检测系统（Arch 系）并安装缺失依赖
2. `make` 编译 dwm → `sudo make install`（默认装到 `/usr/local/bin`）
3. 编译安装 `dwmblocks`
4. 部署 `autostart.sh` 与 `scripts/` 到 `~/.dwm`，并补齐可执行权限
5. 安装 `dwm.desktop` 到 `/usr/share/xsessions/`
6. 写入 fcitx5 环境变量（用户级，见下）并生成 `~/.local/share/fcitx5/rime/default.custom.yaml`
7. 检查 `~/.dwm` 与 dwm 实际查找路径是否一致（见 FAQ）

---

## 🔧 手动安装

```bash
# 1. 依赖
sudo pacman -S --needed base-devel libx11 libxinerama libxft freetype2 fontconfig \
    libxrender kitty rofi feh picom dunst
yay -S fcitx5-im fcitx5-rime rime-ice-git maplemono-cn

# 2. 编译安装
make && sudo make install
make -C dwmblocks && sudo make -C dwmblocks install

# 3. 部署自启与脚本
mkdir -p ~/.dwm
cp autostart.sh ~/.dwm/
cp -r scripts ~/.dwm/
chmod +x ~/.dwm/autostart.sh ~/.dwm/scripts/*.sh

# 4. 会话文件
sudo install -Dm644 dwm.desktop /usr/share/xsessions/dwm.desktop
```

---

## 🩹 已应用的补丁

以下补丁可在 `dwm.c` / `config.h` 中直接验证：

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

补丁文件存放于 `patches/`，说明见 [`patches/README.md`](patches/README.md)。

---

## ⌨️ 快捷键

`MODKEY` = **Super（Win）**。注意本配置中 `MODKEY|Mod4Mask` 与 `MODKEY` 等价，属于冗余绑定（见 FAQ）。

### 启动 / 基础

| 快捷键 | 功能 |
| --- | --- |
| `Super + q` | 打开终端 kitty |
| `Super + r` | 应用启动器 rofi（`rofi -show drun`） |
| ``Super + ` `` | 呼出 / 隐藏暂存终端 scratchpad |
| `Super + b` | 显示 / 隐藏状态栏 |
| `Super + Enter` | 将当前窗口放大为主窗口（zoom） |
| `Super + Tab` | 切回上一个视图 |
| `Super + Shift + c` | 关闭当前窗口 |
| `Super + Shift + q` | 退出 dwm |

### 布局

| 快捷键 | 功能 |
| --- | --- |
| `Super + t` | 平铺 `[]=` |
| `Super + f` | 浮动 `><>` |
| `Super + m` | 单窗口 `[M]` |
| `Super + Space` | 循环切换布局 |
| `Super + Shift + Space` | 切换当前窗口浮动 |
| `Super + Shift + f` | 全屏 |

### 窗口与主区

| 快捷键 | 功能 |
| --- | --- |
| `Super + j` / `k` | 焦点移到下一个 / 上一个窗口 |
| `Super + Shift + j` / `k` | 调整窗口在栈中的顺序 |
| `Super + i` / `d` | 主区窗口数 +1 / −1 |
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

### 标签（桌面）

| 快捷键 | 功能 |
| --- | --- |
| `Super + 1..9` | 切换到标签 1..9 |
| `Super + Ctrl + 1..9` | 在当前标签上追加 / 移除标签 n |
| `Super + Shift + 1..9` | 把当前窗口移动到标签 n |
| `Super + Ctrl + Shift + 1..9` | 切换当前窗口的标签 n |

### 多显示器

| 快捷键 | 功能 |
| --- | --- |
| `Super + ,` / `.` | 聚焦上 / 下一个显示器 |
| `Super + Shift + ,` / `.` | 把当前窗口移到上 / 下一个显示器 |

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

---

## ⚙️ 配置说明

### config.h

改完必须 `make && sudo make install` 重新编译。

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

### blocks.h 与状态栏信号

| 模块 | 脚本 | 间隔(秒) | 信号 |
| --- | --- | --- | --- |
| 网速 | `scripts/wlan.sh` | 1 | — |
| CPU | `scripts/cpu.sh` | 5 | — |
| 内存 | `scripts/memory.sh` | 3 | — |
| 音量 | `scripts/volume.sh` | 0 | **11** |
| 亮度 | `scripts/backlight.sh` | 0 | **11** |
| 电量 | `scripts/battery.sh` | 2 | — |
| 时间 | `scripts/date.sh` | 1 | — |

> 模块之间用 `delim` 分隔，当前为 `" | "`。

> **间隔为 0 的模块只在收到信号时刷新**，也就是音量和亮度。
> 调整音量 / 亮度后需要通知 dwmblocks 刷新：
>
> ```bash
> pkill -RTMIN+11 dwmblocks
> ```
>
> 本配置已在 `config.h` 中把音量 / 亮度调节绑定到 `XF86Audio*` 键并在按键后自动发送该信号。
> 若你新增了 `interval = 0` 的模块，记得同步处理。

### autostart.sh

dwm 启动后会依次执行（见 `dwm.c` 的 `runautostart()`）：

1. `~/.dwm/autostart_blocking.sh`（阻塞执行，本仓库没有此文件，可自行创建）
2. `~/.dwm/autostart.sh`（后台执行）

查找路径顺序：`$XDG_DATA_HOME/dwm` → `~/.local/share/dwm` → `~/.dwm`（**只要前一个目录存在就用它**）。

### 字符字体

状态栏图标依赖 Nerd Font 字形，本配置使用 `Maple Mono CN`：

```bash
yay -S maplemono-cn
```

---

## ⌨️ 输入法（fcitx5 + 雾凇拼音）

`install.sh` 默认会：

1. 写入 `~/.local/share/fcitx5/rime/default.custom.yaml`（已存在则先备份）
2. 写入用户级环境变量，X11 与 Wayland 会话都能生效：

```bash
# ~/.config/environment.d/10-ime.conf   （systemd 图形会话）
# ~/.xprofile                            （startx / X11 会话）
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

## 🗑 卸载

```bash
./install.sh --uninstall
```

会删除：`/usr/local/bin/dwm`、`/usr/local/bin/dwmblocks`、
`/usr/share/xsessions/dwm.desktop`、`~/.dwm`。
不会删除：输入法配置、字体、以及你自行修改过的 `~/.config`。

---

## ❓ 常见问题

**Q：状态栏的音量 / 亮度一直空白？**
它们的 `interval` 为 0，只在收到信号时刷新，见上文「状态栏信号」。

**Q：`Super + 0` 想用来「查看全部标签」，但实际是切换间隙？**
两条绑定都用 `Super + 0`，数组里靠前的 `togglegaps` 先匹配，`view ~0` 与 `tag ~0` 失效。
把 `config.h` 中靠前的那两条注释掉即可恢复。

**Q：`Super + h` 不会调整间隙？**
`MODKEY|Mod4Mask` 在 `MODKEY = Mod4Mask` 时等于 `MODKEY`，与 `setmfact` 冲突，
所以只有靠前的 `setmfact` 生效。间隙请用 `Super + Ctrl + h/l`、`Super + Shift + h/l` 等组合。

**Q：开机进了 dwm 但没有壁纸 / 输入法 / 状态栏？**
1. 确认 `~/.dwm/autostart.sh` 存在且**可执行**（`chmod +x`）
2. 确认 `~/.local/share/dwm` **不存在**，否则 dwm 会用那个目录而忽略 `~/.dwm`
3. 单独运行 `sh -x ~/.dwm/autostart.sh` 看报错

**Q：fcitx5 在 kitty / GTK 应用里打不出中文？**
检查环境变量是否生效（`env | grep IM_MODULE`）、`fcitx5-gtk`/`fcitx5-qt` 是否安装，
以及是否重新登录过。

**Q：状态栏图标显示成方块？**
缺少 `Maple Mono CN` 字体或该字体不含对应 Nerd Font 字形。

**Q：改了 `config.h` / `blocks.h` 没变化？**
两者都是编译期配置，需要重新 `make`（dwm）或 `make -C dwmblocks`，并重新登录。

---

## 📄 许可

- `dwm`、`dwmblocks` 上游代码遵循 MIT / 见各自 `LICENSE`
- 本仓库的配置与脚本部分可自由使用
