


##### 字体

yay -S maplemono-cn

##### 安装dwm

make && sudo make install 

sudo pacman -S xorg kitty rofi Snipaste dunst

sudo systemctl enable lightdm.service
sudo systemctl start lightdm.service

##### 安装显卡驱动
```bash
sudo pacman -S nvidia-utils nvidia-settings nvidia-settings

# 测试
nvidia-smi

```
##### 创建桌面启动项
```bash
sudo pacman -S lightdm
# cp dwm.desktop /usr/share/xsessions/dwm.desktop

"[Desktop Entry]
Encoding=UTF-8
Name=Dwm
Comment=Dynamic window manager
Exec=dwm
Icon=dwm
Type=XSession" >> /usr/share/xsessions/dwm.desktop
```

##### 输入法
```bash
yay -S fcitx5-im fcitx5-rime rime-ice-git

mkdir -p $HOME/.local/share/fcitx5/rime/

"patch:
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
      " >> $HOME/.local/share/fcitx5/rime/default.custom.yaml

<!-- sudo vim /etc/environment -->

echo "GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus" >> /etc/environment
```
##### 额外软件