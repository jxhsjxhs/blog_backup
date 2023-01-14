---
title: docker运行容器后agetty进程cpu占用率100%
date: 2019-07-28 14:23:32
categories: 容器
tags: docker
---

> 最近在使用 docker 容器的时候，发现宿主机的 agetty 进程 cpu 占用率达到 100%。
> ![负载图](/img/newimg/006y8mN6gy1g864u6hjoxj31k00ikjwt.jpg)

在 Google 上搜了下，引起这个问题的原因是在使用"docker run"运行容器时使用了 "/sbin/init"和"--privileged"参数。

使用/sbin/init 启动容器并加上--privileged 参数，相当于 docker 容器获得了宿主机的全权委托权限。这时 docker 容器内部的 init 与宿主机的 init 产生了混淆。

### 引用 google 到的一段话：

> I've done all my testing on them without using --privileged, especially since that's so dangerous (effectively, you're telling this second init process on your system that it's cool to go ahead and manage your system resources, and then giving it access to them as well). I always think of --privileged as a hammer to be used very sparingly.

---

出于对安全的考虑，在启动容器时，docker 容器里的系统只具有一些普通的 linux 权限，并不具有真正 root 用户的所有权限。而--privileged=true 参数可以让 docker 容器具有 linux root 用户的所有权限。

为了解决这个问题，docker 后来的版本中 docker run 增加了两个选项参数"--cap-add"和"--cap-drop"。

--cap-add : 获取 default 之外的 linux 的权限

--cap-drop: 放弃 default linux 权限

> 所以，在运行容器时，可以不用--privileged 参数的尽量不用，用--cap-add 参数替代。如果必须使用--privileged=true 参数的，可以通过在宿主机和容器中执行以下命令将 agetty 关闭。
> shell> systemctl stop getty@tty1.service
> shell> systemctl mask getty@tty1.service
