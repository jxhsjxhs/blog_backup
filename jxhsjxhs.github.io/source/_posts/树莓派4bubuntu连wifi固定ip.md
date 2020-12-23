---
title: 树莓派4bubuntu连wifi固定ip
date: 2020-12-23 12:04:33
tags: ubuntu
---
树莓派4B 安装ubuntu 20.04 LTS wifi配置固定ip

每次都随机比较难找......

1.首先参考之前的那篇 (树莓派 ubuntu 连wifi)

> ubuntu 从18.04 版本开始网络配置工具已经改为netplan了

 

### 编辑netplan目录下的yaml配置文件



sudo vim  /etc/netplan/50-cloud-init.yaml

```yaml
root@ubuntu:~# cat /etc/netplan/50-cloud-init.yaml
# This file is generated from information provided by the datasource.  Changes
# to it will not persist across an instance reboot.  To disable cloud-init's
# network configuration capabilities, write a file
# /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg with the following:
# network: {config: disabled}
network:
    ethernets:
        eth0:
            dhcp4: true
            optional: true
    wifis:
        wlan0:
            access-points:
                "wifi name":
                        password: wifi passwd
            addresses: [192.168.0.101/24]
            gateway4: 192.168.0.1
            nameservers:
              addresses: [8.8.8.8,114.114.114.114]
    version: 2
```



### 检查语法

```
sudo netplan generate
```



# 使配置生效

```
sudo netplan apply
```

# 查看ip地址

```
root@ubuntu:~# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
    link/ether dc:a6:32:cc:25:ab brd ff:ff:ff:ff:ff:ff
3: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether dc:a6:32:cc:25:ad brd ff:ff:ff:ff:ff:ff
    inet 192.168.0.101/24 brd 192.168.0.255 scope global wlan0
       valid_lft forever preferred_lft forever
    inet6 fe80::dea6:32ff:fecc:25ad/64 scope link
       valid_lft forever preferred_lft forever
4: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default
    link/ether 02:42:4f:5f:9b:71 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
```

