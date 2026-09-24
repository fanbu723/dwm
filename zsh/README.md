# zsh 配置说明

这里存放当前在用的 zsh 环境，`install.sh` 会自动部署：

| 仓库路径 | 部署目标 | 内容 |
| --- | --- | --- |
| `zsh/zshrc` | `~/.zshrc` | zsh 主配置（主题、插件、键位绑定） |
| `~/.oh-my-zsh/` | —— | 由脚本从[清华镜像](https://mirrors.tuna.tsinghua.edu.cn/help/ohmyzsh.git/)克隆 |
| `~/.oh-my-zsh/custom/plugins/<name>/` | —— | 两个非自带插件：`zsh-autosuggestions`、`zsh-syntax-highlighting` |

已经存在的 `~/.oh-my-zsh` / 插件目录**不会被覆盖**，脚本只补齐缺失的部分；
`~/.zshrc` 内容不同时会先备份成 `~/.zshrc.bak.<时间戳>` 再写入。

## 手动安装

```bash
# 1. oh-my-zsh（清华镜像，国内更快）
git clone --depth=1 https://mirrors.tuna.tsinghua.edu.cn/git/ohmyzsh.git ~/.oh-my-zsh

# 2. 两个自定义插件
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
    ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
    ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# 3. 配置
cp zsh/zshrc ~/.zshrc

# 4. 改登录 shell，然后重新登录
chsh -s "$(command -v zsh)"
```

## 插件清单

| 插件 | 来源 | 作用 |
| --- | --- | --- |
| `git` | oh-my-zsh 自带 | git 别名与提示符状态 |
| `gitfast` | oh-my-zsh 自带 | 更快的 git 补全 |
| `z` | oh-my-zsh 自带 | 按访问频率跳转目录（数据存在 `~/.z`） |
| `sudo` | oh-my-zsh 自带 | 连按两次 `Esc`，给当前命令补上 `sudo` |
| `extract` | oh-my-zsh 自带 | `x <压缩包>` 自动选择解压工具 |
| `colored-man-pages` | oh-my-zsh 自带 | man 手册彩色输出 |
| `command-not-found` | oh-my-zsh 自带 | 命令不存在时提示所属软件包 |
| `history-substring-search` | oh-my-zsh 自带 | ↑/↓ 按前缀搜索历史（键位见 `zshrc`） |
| `copypath` | oh-my-zsh 自带 | `copypath` 复制当前目录路径 |
| `copyfile` | oh-my-zsh 自带 | `copyfile <文件>` 复制文件内容 |
| `zsh-autosuggestions` | 自定义 | 根据历史给灰色建议，→ 补全 |
| `zsh-syntax-highlighting` | 自定义 | 命令语法高亮（**必须放最后**） |

需要额外插件时，克隆到 `~/.oh-my-zsh/custom/plugins/<名字>/`，再把名字加进 `zsh/zshrc`
的 `plugins=(...)` 即可（本机还装了 `fzf-tab`，但没有启用，想用就手动加进列表）。

## 镜像 / 代理

脚本支持两个环境变量覆盖默认地址（不改代码）：

```bash
# oh-my-zsh 换源
DWM_OMZ_GIT_URL=https://github.com/ohmyzsh/ohmyzsh ./install.sh

# 自定义插件走 GitHub 代理（前缀形式）
ZSH_GH_MIRROR=https://ghproxy.net/https://github.com ./install.sh
```
