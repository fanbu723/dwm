# 我用的补丁

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

## 归档情况

本目录只保存了 `fullscreen` 与 `scratchpad` 两个 diff，其余补丁已经打进 `dwm.c`，
但没有归档原始 diff。补丁是否生效以代码为准：

| 补丁 | 在 dwm.c 中的状态 |
| ---------------- | ---------------------------------------------- |
| vanitygaps | ✅ 已应用（`config.h` 的 `gappih/gappiv/gappoh/gappov`、`incrgaps`） |
| alphasystray | ✅ 已应用（`baralpha`、`alphas[]`、`showsystray`） |
| awesomebar | ✅ 已应用（`enum SchemeHid`、`togglewin`） |
| pertag | ✅ 已应用（缺少它 `Super+0` 前的 `pertag` 结构不存在） |
| fullscreen | ✅ 已应用（`fullscreen()` 与 `Super+Shift+f`） |
| scratchpad | ✅ 已应用（`togglescratch()` 与 ``Super+` ``） |
| rotatestack | ✅ 已应用（`rotatestack()` 与 `Super+Shift+j/k`） |
| autostart | ✅ 已应用（`runautostart()`） |
| hide_vacant_tags | ❌ 代码中未检测到 |
| noborder | ❌ 代码中未检测到 |
| accessnthmonitor | ❌ 代码中未检测到 |
| statuscmd | ❌ 未应用，因此点击状态栏不会给 dwmblocks 发信号；音量/亮度由 `config.h` 的快捷键发送 `pkill -RTMIN+11 dwmblocks` 刷新 |

## 打补丁

dwm 源码在 `src/`，所以补丁要指定目录：

```sh
patch -d src -p1 < patches/dwm-fullscreen-6.2.diff
```

打完后重新编译：`make -C src && sudo make -C src install`。

注意：本目录中的 diff 基于 dwm 6.2，而当前源码为 dwm 6.4，
直接应用很可能出现 hunk failed，请以 `src/dwm.c` 的实际代码为准。

补丁来源：<https://dwm.suckless.org/patches/>
