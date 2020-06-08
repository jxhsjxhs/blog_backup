---
title: 一次简单的pod Evicted排查
date: 2020-06-03 10:54:31
tags:
---

早上开发人员反馈一个测试集群经常有后端或者其他的程序无故挂掉。由于是开发自测环境 常年没人维护，上去一看发现很多pod都是`evicted`状态居然s达到了2000多个。。
不过也没大事儿，`evicted`都是驱逐 要么是标签驱逐 要么是资源驱逐。都很好解决
![](https://tva1.sinaimg.cn/large/007S8ZIlgy1gfewxmle3gj311o0ds7o3.jpg)

具体查看某个pod的日志可知.
```
kubectl describe pod  xxxxxx
```
![](https://tva1.sinaimg.cn/large/007S8ZIlgy1gfewxyocsbj312x09fdrk.jpg)

日志显示的是节点的磁盘不足导致。加相关目录磁盘即可解决。
lvm扩容磁盘步骤
```
[root@node2 ~]# vgextend centos /dev/sdb
[root@node2 ~]# lvextend -L +190G  /dev/centos/root
[root@node2 ~]#  xfs_growfs /dev/centos/root

[root@node2 ~]# lsblk
NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda               8:0    0   50G  0 disk
├─sda1            8:1    0    2G  0 part /boot
└─sda2            8:2    0   48G  0 part
  ├─centos-root 253:0    0  230G  0 lvm  /
  └─centos-swap 253:1    0    8G  0 lvm
sdb               8:16   0  200G  0 disk
└─centos-root   253:0    0  230G  0 lvm  /
sr0              11:0    1 1024M  0 rom
```
完事了。

---


现有的`evicted`pod可以用命令一起删除
```
 kubectl get pods   | grep Evicted | awk '{print $1}' | xargs kubectl delete pod
```

默认由于资源的驱逐规则
```
memory.available<100Mi
nodefs.available<10%
nodefs.inodesFree<5%
imagefs.available<15%

```

### 官方文档
[官网解读kubernetes配置资源不足处理](https://kubernetes.io/zh/docs/tasks/administer-cluster/out-of-resource/)