# 补丁说明

这里记录 dwm 补丁的备选清单、**实际应用状态**，以及归档的原始 diff。

> 判断某个补丁到底有没有生效，**一律以 `src/dwm.c` 的实际代码为准**，
> 不要只看下面这张功能表（它只是备选清单，不代表全都装了）。
> 核对方法见文末「核对方法」。

## 补丁清单（功能速查）

| 名称             | 功能                                          |
| ---------------- | --------------------------------------------- |
| alphasystray     | 让状态栏有半透明的效果，并增加系统托盘        |
| autostart        | 让 dwm 在启动时自动启动一个脚本               |
| awesomebar       | 让状态栏显示当前桌面的所有窗口的名称          |
| fullscreen       | 让窗口可以全屏                                |
| hide_vacant_tags | 让状态栏只显示有窗口的桌面的标签              |
| noborder         | 当只有一个窗口时，去除窗口的边框              |
| pertag           | 不同的桌面保持不同的窗口管理方式              |
| rotatestack      | 能调整窗口摆放顺序                            |
| scratchpad       | 能临时打开一个小窗口并在任意桌面都能显示      |
| vanitygaps       | 在窗口之间增加一个小的空隙                    |
| accessnthmonitor | 到达第n个显示器，用于在多显示器环境中直接切换 |

## 应用状态

上表中的 11 个补丁**只有 8 个真正生效**，其余 3 个只是备选，代码里并不存在；
另外 `statuscmd` 也未应用。本目录的 diff 也**只归档了** `fullscreen` 与 `scratchpad` 两个。

### 已应用（已打进 `dwm.c`）

| 补丁 | 作用 | 代码中的标志 |
| --- | --- | --- |
| vanitygaps | 在窗口之间留出间隙 | `incrgaps` / `incrihgaps` / `incrovgaps`，`config.h` 的 `gappih` `gappiv` `gappoh` `gappov` |
| alphasystray | 状态栏半透明 + 系统托盘 | `baralpha`、`alphas[]`、`showsystray` |
| awesomebar | 状态栏显示窗口标题与隐藏态、点击标题切窗口 | `enum SchemeHid`、`togglewin()` |
| pertag | 每个标签独立记忆布局与参数 | `struct Pertag`、`m->pertag->*` |
| fullscreen | 窗口全屏（`Super + Shift + f`） | `fullscreen()` |
| scratchpad | 任意标签都能呼出暂存终端（``Super + ` ``） | `togglescratch()` |
| rotatestack | 调整窗口在栈中的顺序（`Super + Shift + j/k`） | `rotatestack()` |
| autostart | 启动时执行 `~/.dwm/autostart.sh` | `runautostart()` |

### 未应用（仅备选，`dwm.c` 中不存在）

| 补丁 | 作用 | 未应用带来的影响 |
| --- | --- | --- |
| hide_vacant_tags | 状态栏只显示有窗口的标签 | 空标签也会显示 |
| noborder | 只有一个窗口时去掉边框 | 单窗口仍有边框（`borderpx = 1`） |
| accessnthmonitor | 直接跳到第 n 个显示器 | 只能用 `Super + ,` / `.` 循环切换显示器 |
| statuscmd | 点击状态栏时给 dwmblocks 发信号 | 点击状态栏不会刷新模块；音量 / 亮度改由 `config.h` 的快捷键发送 `pkill -RTMIN+11 dwmblocks` 刷新 |

## 归档的 diff

本目录只保存了两个原始 diff：

```
patches/dwm-fullscreen-6.2.diff
patches/dwm-scratchpad-6.2.diff
```

其余已应用的补丁没有归档 diff。归档时请注意：

* 这两个 diff 基于 **dwm 6.2**，而当前源码是 **dwm 6.4**，直接应用很可能出现 hunk failed。
* 这两个补丁在 `dwm.c` 里**已经存在**，正常情况下不需要再打一遍，归档仅作参考。
* `.gitignore` 里有 `patches/*.diff` 规则，新增 diff 需要 `git add -f patches/xxx.diff` 才会被跟踪。

## 打补丁

dwm 源码在 `src/`，所以打补丁要指定目录：

```sh
patch -d src -p1 < patches/dwm-fullscreen-6.2.diff
```

打完后重新编译：`make -C src && sudo make -C src install`（或直接 `./install.sh`）。

## 核对方法

直接 grep 函数名或结构体名，就能确认补丁在不在：

```sh
grep -nE 'rotatestack|togglescratch|togglewin|runautostart|fullscreen|Pertag' src/dwm.c
```

补丁来源：<https://dwm.suckless.org/patches/>
