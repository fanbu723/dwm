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
| focusonnetactive | 响应 `_NET_ACTIVE_WINDOW`（点通知跳窗口要用）  |
| fullscreen       | 让窗口可以全屏                                |
| hide_vacant_tags | 让状态栏只显示有窗口的桌面的标签              |
| noborder         | 当只有一个窗口时，去除窗口的边框              |
| pertag           | 不同的桌面保持不同的窗口管理方式              |
| rotatestack      | 能调整窗口摆放顺序                            |
| scratchpad       | 能临时打开一个小窗口并在任意桌面都能显示      |
| vanitygaps       | 在窗口之间增加一个小的空隙                    |
| accessnthmonitor | 到达第n个显示器，用于在多显示器环境中直接切换 |

## 应用状态

上表中的 12 个补丁**只有 9 个真正生效**，其余 3 个只是备选，代码里并不存在；
另外 `statuscmd` 也未应用。本目录的 diff 也**只归档了** `fullscreen` 与 `scratchpad` 两个。

### 已应用（已打进 `dwm.c`）

| 补丁 | 作用 | 代码中的标志 |
| --- | --- | --- |
| vanitygaps | 在窗口之间留出间隙 | `incrgaps` / `incrihgaps` / `incrovgaps`，`config.h` 的 `gappih` `gappiv` `gappoh` `gappov` |
| alphasystray | 状态栏半透明 + 系统托盘 | `baralpha`、`alphas[]`、`showsystray` |
| awesomebar | 状态栏把本标签的窗口平铺成任务条（隐藏的变青色），点击切换 / 隐藏 / 恢复窗口 | `enum SchemeHid`、`hide()` / `show()`、`togglewin()`、`m->bt` / `m->btw` |
| pertag | 每个标签独立记忆布局与参数 | `struct Pertag`、`m->pertag->*` |
| fullscreen | 窗口全屏（`Super + Shift + f`） | `fullscreen()` |
| scratchpad | 任意标签都能呼出暂存终端（``Super + ` ``） | `togglescratch()` |
| rotatestack | 调整窗口在栈中的顺序（`Super + Shift + j/k`） | `rotatestack()` |
| autostart | 启动时执行 `~/.dwm/autostart.sh` | `runautostart()` |
| focusonnetactive | 外部程序请求激活窗口时（`wmctrl -a` / `xdotool windowactivate`，即 dunst 通知菜单里点「↗ 打开」）切到它所在的显示器 / 标签并聚焦 | `config.h` 的 `focusonnetactive`、`clientmessage()` 里的 `netatom[NetActiveWindow]` 分支 |

### 未应用（仅备选，`dwm.c` 中不存在）

| 补丁 | 作用 | 未应用带来的影响 |
| --- | --- | --- |
| hide_vacant_tags | 状态栏只显示有窗口的标签 | 空标签也会显示 |
| noborder | 只有一个窗口时去掉边框 | 单窗口仍有边框（`borderpx = 1`） |
| accessnthmonitor | 直接跳到第 n 个显示器 | 只能用 `Super + ,` / `.` 循环切换显示器 |
| statuscmd | 点击状态栏时给 dwmblocks 发信号 | 点击状态栏不会刷新模块；音量 / 亮度改由 `config.h` 的快捷键发送 `pkill -RTMIN+11 dwmblocks` 刷新 |

> `focusonnetactive` 是按上游同名补丁的思路**手写**的精简实现（上游的 diff 基于 6.2），
> 没有归档 diff：`src/dwm.c` 里 `clientmessage()` 的 `netatom[NetActiveWindow]` 分支就是它的全部代码。
> 上游 dwm 对这个请求只给窗口置「紧急」标记（边框变色）而不抢焦点，所以不打这个补丁时，
> 点 dunst 通知菜单只会让目标窗口闪一下。

> `awesomebar` 只在状态栏中部（任务条）生效，要三处配合，改一处得同时看另两处：
> `drawbar()` 把本标签的窗口平铺成等宽分段，并记下 `m->bt`（窗口数）/ `m->btw`（任务区总宽）；
> `buttonpress()` 用同一套宽度把点击的 x 反查成窗口（塞进 `arg.v`）再交给 `togglewin()`；
> `config.h` 的 `alphas[]` 必须跟 `colors[]` 一样补上 `[SchemeHid]`，因为 `setup()` 是按
> `LENGTH(colors)` 取 `alphas[i]` 建色板的，少一项就是越界读。
> 上游 6.2 的 diff 还带 `HIDDEN()`（`focus()` / `nexttiled()` 里跳过隐藏窗口）、`hide()` / `show()`，
> 这些在本仓库里都已保留。
>
> 历史坑：dwm 6.4 重写过的 `buttonpress()` 里**没有**「反查窗口」那几行时，`arg.v` 恒为 NULL，
> `togglewin()` 拿 NULL 去 `HIDDEN()` 就是向 X 查询窗口 0 → BadWindow → `xerror()` 里 `die()`，
> 表现就是「点一下状态栏窗口名 dwm 直接退出」。现在 `togglewin()` 遇到 NULL 直接返回。

> 「长按 Super 弹窗口预览」+ `Super + Tab` / `Super + Shift + Tab` 切窗口（`previewshow()`、
> `previewdraw()`、`previewlist()`、`previewhide()`、`switchwin()`、`keyrelease()`、`superkeydown()`）
> 不来自上游任何补丁，是本仓库自己写的：`grabkeys()` 单独抓 Super 键，`run()` 用带超时的
> `select` 判长按，预览浮层是自己建的 override_redirect 窗口（不参与管理，也不吃鼠标）。
> 改这块要注意两件事：浮层内容画在状态栏那个 pixmap 上、但窗口原点不同，所以用
> `XCopyArea` 而不是 `drw_map()`；以及浮层取消映射时会产生一个假的 `EnterNotify`（指针
> 「进入」下面那个窗口），必须在设焦点前吃掉它。

> 状态栏文字的颜色标记（`^c#RRGGBB^` / `^d^`，`statusparse()`、`statuswidth()`、`drawstatus()`、
> `statusclrget()`）也是自己写的精简版，只做前景色，没搬上游 `statuscolors` / `status2d` 那套
> 背景色 / 画矩形。注意量宽度、算点击区间都得用 `statuswidth()`（跳过标记），
> 而且 `drw_text()` 渲染时返回的是**矩形右边界**（`x + (render ? w : 0)`）而不是文字末尾，
> 分段画的时候光标要自己按 `drw_fontset_getwidth()` 往前推。

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
grep -nE 'rotatestack|togglescratch|togglewin|runautostart|fullscreen|Pertag|focusonnetactive' src/dwm.c
```

补丁来源：<https://dwm.suckless.org/patches/>
