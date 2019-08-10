---
title: 'Mac brew 特别慢 解决方案 '
date: 2019-08-09 14:09:35
tags:
---

众所周知，brew是mac下最好的下载软件工具，类似与yum、apt有过之而不及。(如果没听过，请关闭该网页)

接下来解决特别慢的问题。
1.按照常规安装安装好brew
`/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`
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
4.愉快的玩耍。
