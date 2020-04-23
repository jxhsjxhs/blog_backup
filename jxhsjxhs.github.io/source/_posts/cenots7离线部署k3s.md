---
title: cenots7离线部署k3s
date: 2020-01-16 00:24:12
tags:
---

### K3S简介：
> https://k3s.io/
> https://github.com/rancher/k3s
> https://github.com/rancher/k3s/releases      //版本及images
![](https://tva1.sinaimg.cn/large/006tNbRwgy1gb315kdc6qj31ag0heq89.jpg)

总的来说就是轻量级k8s,master只要500M内存就能跑,一般场景是边缘计算或者本地测试k8s环境.

###  部署环境
```
k3s      
docker-ce
centos7.6
```

### docker-ce安装
参考：

[centos7.6在线yum安装docker-ce](https://www.cnblogs.com/xiaochina/p/11518007.html)
[基于Centos7.5搭建Docker环境](https://www.cnblogs.com/xiaochina/p/7074796.html)
[centos7下docker二进制安装](https://www.cnblogs.com/xiaochina/p/10469715.html)

###  导入k3s镜像
下载 https://github.com/rancher/k3s/releases/download/v1.17.0%2Bk3s.1/k3s-airgap-images-amd64.tar  (注意自己的平台架构比如 x86,arm32,arm64)

docker load -i k3s-airgap-images-amd64.tar 
```
Loaded image: docker.io/coredns/coredns:1.3.0
Loaded image: docker.io/library/traefik:1.7.12
Loaded image: docker.io/rancher/klipper-helm:v0.1.5
Loaded image: docker.io/rancher/klipper-lb:v0.1.1
Loaded image: k8s.gcr.io/pause:3.1
```

### 部署k3s server/agent
https://github.com/rancher/k3s/releases/download/v0.9.0/k3s   //下载二进制k3s

https://raw.githubusercontent.com/rancher/k3s/master/install.sh    //k3s安装脚本，具体可以看下脚本存在很多变量定义

export INSTALL_K3S_SKIP_DOWNLOAD=true           //设置跳过下载k3s二进制文件
export INSTALL_K3S_BIN_DIR=/usr/bin       //设置k3s安装目录
./install.sh       //自动建立service服务及软连接  kubectl ctr  ....

systemctl status k3s    //服务运行状态

journalctl -u k3s -f     //根据日志可以看到服务启动不起来,要去国外拉images，你懂得，heihei

### 修正k3s服务改用docker
vi /etc/systemd/system/k3s.service
ExecStart=/usr/bin/k3s \
server --docker\              //注意 两个杠，容器选择docker，替换默认的containerd

systemctl daemon-reload    //刷新服务配置文件，重新定向到target
systemctl restart k3s

![](https://tva1.sinaimg.cn/large/006tNbRwgy1gb31og03w8j30t70dr0u4.jpg)
k3s的pod运行在docker之中
![](https://tva1.sinaimg.cn/large/006tNbRwgy1gb31onpelnj312k0faq6h.jpg)


### 安装错误记录
在树莓派4装的ubuntu 18.04 LTS 系统中跑k3s发现如下错误
![](https://tva1.sinaimg.cn/large/007S8ZIlgy1ge3n7e4opzj31fr0u07wi.jpg)
关键报错信息：
```
level=error msg="Failed to find memory cgroup, you may need to add \"cgroup_memory=1 cgroup_enable=memory\" to your linux cmdline (/boot/cmdline.txt on a Raspberry Pi)"
```

### 排查记录
日志提示很明显，所以我们修改/boot/cmdline.txt并重启，但是重启后发现问题依旧，还是有这个问题。这个修改的本质是添加内核参数，所以我们从操作系统层面检查：

> $ cat /proc/cmdline | grep cgroup_memory
> nothing return

也就是说，cmdline的修改没有生效。所以，我们怀疑ubuntu这个镜像修改cmdline有其他方式：
```

$ df -hT | grep mmc
/dev/mmcblk0p2 ext4       29G  2.8G   26G  10% /
/dev/mmcblk0p1 vfat      253M  117M  136M  47% /boot/firmware
# 真正的启动分区在/boot/firmware

# 阅读/boot/firmware/README
# 排查后得知，应该修改nobtcmd.txt
```

在/boot/firmware/nobtcmd.txt添加cgroup相关参数后，重启后可以看到cmdline有了期望的配置：

```
$ cat /proc/cmdline | grep cgroup_memory
coherent_pool=1M ………. cgroup_memory=1 cgroup_enable=memory
```

这时发现k3s依然没有完成启动，日志输出缓慢，怀疑系统某些因素影响了启动过程。排查entropy，发现可用值非常低，低到会阻塞程序运行，一般来说<1000程序就会卡住
```
$ cat /proc/sys/kernel/random/entropy_avail
522
```

很多程序的运行都依赖随机数生成，比如hash、加密解密等过程。申请随机数就会消耗系统的entropy（熵），当entropy低到一定阈值，程序就运行缓慢，等待随机数种子。

一般来说kernel可以从硬件运行信息中收集噪声来补充entropy，但树莓派毕竟硬件能力有限，无法从硬件层面快速生成entropy，所以我们安装软件提供模拟算法进行补充：

```
$ apt install haveged 
$ systemctl enable haveged

$ cat /proc/sys/kernel/random/entropy_avail
2366
```

一切妥当之后，再查看k3s启动状态，k3s已经完成启动。

### 总结

Linux运行在诸如树莓派这种简易硬件架构下，会有很多细微差别，平日在x86 server体系的认知和经验可能都是不成立，这就导致运行在服务器Linux上的软件并不会那么容易移植到小型终端设备上。对于树莓派，除了文中提及的内容，你还需要关注NTP时间同步，MicroSD卡的IO性能等等。


参考
[树莓派安装k3s报错](https://my.oschina.net/u/4407852/blog/3198647/print)

