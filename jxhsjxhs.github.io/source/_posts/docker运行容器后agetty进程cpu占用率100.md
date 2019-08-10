---
title: docker运行容器后agetty进程cpu占用率100%
date: 2019-07-28 14:23:32
categories: 容器
tags: docker
---
>最近在使用docker容器的时候，发现宿主机的agetty进程cpu占用率达到100%。
>![负载图](docker运行容器后agetty进程cpu占用率100%/docker.png)


在Google上搜了下，引起这个问题的原因是在使用"docker run"运行容器时使用了 "/sbin/init"和"--privileged"参数。

使用/sbin/init启动容器并加上--privileged参数，相当于docker容器获得了宿主机的全权委托权限。这时docker容器内部的init与宿主机的init产生了混淆。

### 引用google到的一段话：

> I've done all my testing on them without using --privileged, especially since that's so dangerous (effectively, you're telling this second init process on your system that it's cool to go ahead and manage your system resources, and then giving it access to them as well). I always think of --privileged as a hammer to be used very sparingly.

---

出于对安全的考虑，在启动容器时，docker容器里的系统只具有一些普通的linux权限，并不具有真正root用户的所有权限。而--privileged=true参数可以让docker容器具有linux root用户的所有权限。

 

为了解决这个问题，docker后来的版本中docker run增加了两个选项参数"--cap-add"和"--cap-drop"。

--cap-add : 获取default之外的linux的权限

--cap-drop: 放弃default linux权限



> 所以，在运行容器时，可以不用--privileged参数的尽量不用，用--cap-add参数替代。如果必须使用--privileged=true参数的，可以通过在宿主机和容器中执行以下命令将agetty关闭。
> shell> systemctl stop getty@tty1.service
> shell> systemctl mask getty@tty1.service
