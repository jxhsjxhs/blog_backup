---
title: 'pi4B  kubelet  Following Cgroup subsystem not mounted '
date: 2020-10-22 12:10:45
tags:
---

### 背景
```
在树莓派4B中安装了ubuntu 20.04.1 LTS 然后接入k8s(kubeedge)集群。
```

### 现象
![pi4.png](https://i.loli.net/2020/10/22/GhPvMuNeEfdtKF4.png)

发现kubelet一直启动不起来,报错为 `Following Cgroup subsystem not mounted: [memory]`
大概意思是主机没有挂载内存的Cgroup，但是kubelet是需要控制cpu以及内存的Cgroup。所以启动不起来

### 处理过程
知道问题了,但是百度了半天大家都说是需要在`/boot/cmdline.txt` 中加入`cgroup_enable=memory cgroup_memory=1`然后重启即可。
但是重启问题依旧，然后查看引导
```
cat /boot/firmware/config.txt
```
![image.png](https://i.loli.net/2020/10/22/kXeqVdLz6iRJQgO.png)


发现还是这个名字,最后实在没办法就吧`cmdline.txt`放到了`/boot/firmware/`下。然后就成功了 


### 心得
只是记录一下坑，毫无卵用。