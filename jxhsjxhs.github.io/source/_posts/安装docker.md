---
title: 安装docker
date: 2020-10-26 22:57:34
tags:
---

在物联网以及arm板子安装docker比较麻烦。直接用官方的安装脚本然后用阿里的源安装会比较方便
hin简单

curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun

配置阿里源镜像
sudo mkdir -p /etc/docker 
sudo tee /etc/docker/daemon.json <<-'EOF' 
{ 
    "registry-mirrors": ["https://55bqr8pu.mirror.aliyuncs.com"] 
} 
EOF sudo systemctl daemon-reload sudo systemctl restart docker

完事。