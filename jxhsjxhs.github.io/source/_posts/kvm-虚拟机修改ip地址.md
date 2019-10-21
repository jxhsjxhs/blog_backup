---
title: kvm 虚拟机修改ip地址
date: 2019-07-31 23:20:18
categories: 虚拟化
tags: kvm
---

## KVM 虚拟化之 libguestfs-tools 工具常用命令介绍

> 背景:由于 kvm 虚拟机没有图形化界面，导致模版克隆的虚拟机更改 ip 很不方便。需要一台台手动登陆去修改，而 libguestfs-tools 工具能做到给克隆出来的虚拟机更改 ip，写成脚本后非常方便使用。
>
> ### 安装
>
> ```
> yum -y install libguestfs-tools
> ```

## 使用

> libguestfs-tools 工具的部分命令使用方便，但是执行速度不是很快，下面只对一些常用命令进行介绍
> ![libguestfs-tools工具命令](https://tva1.sinaimg.cn/large/006y8mN6gy1g864vcr9hlj31nw0aijyl.jpg)
> 1.virt-df
> 介绍：类似于虚拟机本地“df”命令
> ![virt-df](https://tva1.sinaimg.cn/large/006y8mN6gy1g8652z1kfsj31as05w0wp.jpg)
> 2.virt-cat
> 介绍：类似于虚拟机本地“cat”命令
> ![virt-cat](https://tva1.sinaimg.cn/large/006y8mN6gy1g86537buvij31c604k0wa.jpg)
> 3.virt-edit
> 介绍：类似于虚拟机本地”vi”命令，使用这个命令需要关闭虚拟机
> ![virt-edit](https://tva1.sinaimg.cn/large/006y8mN6gy1g8653sy7d0j31b609waht.jpg)
> 4.virt-ls
> 介绍：类似于虚拟机本地”ls”命令
> ![virt-ls](https://tva1.sinaimg.cn/large/006y8mN6gy1g8653zq34qj30su0ac0vz.jpg)
> 5.virt-copy-out
> 介绍：复制虚拟机文件到宿主机本地磁盘，类似于本地”cp”命令
> ![virt-copy-out](https://tva1.sinaimg.cn/large/006y8mN6gy1g86547qc0qj313s04sgoa.jpg)
> 6.virt-copy-in
> 介绍：复制宿主机本地文件到虚拟机磁盘，类似于本地”cp”命令
> ![virt-copy-in](https://tva1.sinaimg.cn/large/006y8mN6gy1g8654erb43j314s08879p.jpg)

### 注意 virt-copy-in 以及 virt-edit 命令 需要关闭虚拟机才能执行

> ![error](https://tva1.sinaimg.cn/large/006y8mN6gy1g8654nhqrwj31b607m45b.jpg)
