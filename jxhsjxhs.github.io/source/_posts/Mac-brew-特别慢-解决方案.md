---
title: 'Mac brew 特别慢 解决方案 '
date: 2019-08-09 14:09:35
categories: 杂项 
tags: mac
---
更新一下,下面的方法都过时了。

直接一条命令耍完整个安装加换源。
1. 执行命令：

/bin/zsh -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)"

2. 输入编号选择下载源

![](/img/newimg/0081Kckwgy1glxqervyuxj30xx0e5gvz.jpg)




众所周知，brew是mac下最好的下载软件工具，类似与yum、apt有过之而不及。(如果没听过，请关闭该网页)

接下来解决特别慢的问题。
1.按照常规安装安装好brew
```
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```
2.替换brew.git:
```
cd "$(brew --repo)"
git remote set-url origin https://mirrors.ustc.edu.cn/brew.git
```
3.替换homebrew-core.git:
```
cd "$(brew --repo)/Library/Taps/homebrew/homebrew-core"
git remote set-url origin https://mirrors.ustc.edu.cn/homebrew-core.git 
```
4.什么?你连安装第一步都卡?请关闭该网页！
5.开个玩笑,第一步执行卡可以换源下载brew
- 获取 install 文件
```
curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install >> brew_install
```
如果这个你访问不了,连手机热点 然后加hosts。稳稳的

- 更改脚本中的资源链接
换成清华大学的镜像，修改如下两句.
```
BREW_REPO = “https://github.com/Homebrew/brew“.freeze 
CORE_TAP_REPO = “https://github.com/Homebrew/homebrew-core“.freeze 
```
更改为这两句(或者你找的其他家的)
```
BREW_REPO = "https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git".freeze 
CORE_TAP_REPO = "https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git".freeze
```
- 运行脚本
```
/usr/bin/ruby brew_install
```
- 可以愉快玩耍了