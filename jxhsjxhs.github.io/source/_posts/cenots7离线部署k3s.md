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
server --docker\              //容器选择docker，替换默认的containerd

systemctl daemon-reload    //刷新服务配置文件，重新定向到target
systemctl restart k3s

![](https://tva1.sinaimg.cn/large/006tNbRwgy1gb31og03w8j30t70dr0u4.jpg)
k3s的pod运行在docker之中
![](https://tva1.sinaimg.cn/large/006tNbRwgy1gb31onpelnj312k0faq6h.jpg)