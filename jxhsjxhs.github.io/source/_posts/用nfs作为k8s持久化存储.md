---
title: 用nfs作为k8s持久化存储
date: 2019-10-25 13:57:26
categories: 容器
tags: k8s,nfs
---

## kubernetes部署NFS持久存储

### NFS简介
> NFS是网络文件系统Network File System的缩写，NFS服务器可以让PC将网络中的NFS服务器共享的目录挂载到本地的文件系统中，而在本地的系统中来看，那个远程主机的目录就好像是自己的一个磁盘分区一样。
> ```
> kubernetes使用NFS共享存储有两种方式：
> 手动方式静态创建所需要的PV和PVC。
> 通过创建PVC动态地创建对应PV，无需手动创建PV。
> 这条博客是写的静态创建方法
> ```
可以发现k8s中的Volume（无论何种类型）和使用它的Pod都是一种静态绑定关系，在Pod定义文件中，同时定义了它使用的Volume。在这种情况下，Volume是Pod的附属品，我们无法像创建其他资源（例如Pod，Node，Deployment等等）一样创建一个Volume。

因此Kubernetes提出了PersistentVolume（PV）的概念。PersistentVolume和Volume一样，代表了集群中的一块存储区域，然而Kubernetes将PersistentVolume抽象成了一种集群资源，类似于集群中的Node对象，这意味着我们可以使用Kubernetes API来创建PersistentVolume对象。PV与Volume最大的不同是PV拥有着独立于Pod的生命周期。

而PersistentVolumeClaim（PVC）代表了用户对PV资源的请求。用户需要使用PV资源时，只需要创建一个PVC对象（包括指定使用何种存储资源，使用多少GB，以何种模式使用PV等信息），Kubernetes会自动为我们分配我们所需的PV。如果把PersistentVolume类比成集群中的Node，那么PersistentVolumeClaim就相当于集群中的Pod，Kubernetes为Pod分配可用的Node，为PersistentVolumeClaim分配可用的PersistentVolume。


### 搭建nfs服务器
这里作为测试，临时在master节点上部署NFS服务器。
```
#master节点安装nfs
yum -y install nfs-utils

#创建nfs目录
mkdir -p /data/nfs/

#修改权限
chmod -R 777 /data/nfs

#编辑export文件
vim /etc/exports
/data/nfs *(rw,no_root_squash,sync)

#配置生效
exportfs -r
#查看生效
exportfs

#启动rpcbind、nfs服务
systemctl restart rpcbind && systemctl enable rpcbind
systemctl restart nfs && systemctl enable nfs

#查看 RPC 服务的注册状况
rpcinfo -p localhost

#showmount测试
showmount -e 10.7.150.112

#所有node节点安装客户端
yum -y install nfs-utils
systemctl start nfs && systemctl enable nfs
```
> 作为准备工作，我们已经在 k8s-master 节点上搭建了一个 NFS 服务器，目录为 /data/nfs.

### 静态申请PV卷

#### 添加pv卷对应目录,作为挂载点
```
#创建pv卷对应的目录
mkdir -p /nfs/data/pv001

#配置exportrs
vim /etc/exports
/nfs/data *(rw,no_root_squash,sync)
/nfs/data/pv001 *(rw,no_root_squash,sync)

#配置生效
exportfs -r
#重启rpcbind、nfs服务
systemctl restart rpcbind && systemctl restart nfs
```

#### 创建PV
```
`
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv
  labels:
    pv: nfs-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Recycle
  storageClassName: nfs
  nfs:
    path: /nfs/data/pv
    server: 10.7.150.112
`
```
--- 

```
`配置说明`：
capacity 指定 PV 的容量为 1G。
accessModes 指定访问模式为 ReadWriteOnce，支持的访问模式有：
ReadWriteOnce – PV 能以 read-write 模式 mount 到单个节点。
ReadOnlyMany – PV 能以 read-only 模式 mount 到多个节点。
ReadWriteMany – PV 能以 read-write 模式 mount 到多个节点。
persistentVolumeReclaimPolicy 指定当 PV 的回收策略为 Recycle，支持的策略有：
Retain – 需要管理员手工回收。
Recycle – 清除 PV 中的数据，效果相当于执行 rm -rf /thevolume/*。
Delete – 删除 Storage Provider 上的对应存储资源，例如 AWS EBS、GCE PD、Azure
Disk、OpenStack Cinder Volume 等。
storageClassName 指定 PV 的 class 为 nfs。相当于为 PV 设置了一个分类，PVC 可以指定 class 申请相应 class 的 PV。
指定 PV 在 NFS 服务器上对应的目录。
```
![create PV](https://tva1.sinaimg.cn/large/006y8mN6gy1g8ctzzzc76j30wm03kaaq.jpg)

> STATUS 为 Available，表示 pv就绪，可以被 PVC 申请。

#### 创建PVC
接下来创建一个名为pvc的PVC，配置文件 pvc.yaml
```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: nfs
  selector:
    matchLabels:
      pv: nfs-pv

```

![Bound PVC](https://tva1.sinaimg.cn/large/006y8mN6gy1g8cu33t8lsj30xo06kmyk.jpg)

> 从 kubectl get pvc 和 kubectl get pv 的输出可以看到pvc绑定成功，注意pvc绑定到对应pv通过labels标签方式实现，也可以不指定，将随机绑定到pv。

---

接下来就可以在 Pod 中使用存储了，Pod 配置文件 pod.yaml
```
kind: Pod
apiVersion: v1
metadata:
  name: nfs-pod001
spec:
  containers:
    - name: myfrontend
      image: nginx
      volumeMounts:
      - mountPath: "/var/www/html"
        name: nfs-pv
  volumes:
    - name: nfs-pv
      persistentVolumeClaim:
        claimName: nfs-pvc
```
> 与使用普通 Volume 的格式类似，在 volumes 中通过 persistentVolumeClaim 指定使用nfs-pvc 申请的 Volume

![create pod](https://tva1.sinaimg.cn/large/006y8mN6gy1g8cu7x6628j30go03tt97.jpg)

验证PV是否可用
![file](https://tva1.sinaimg.cn/large/006y8mN6gy1g8cu8qrjnpj30pg02yjrt.jpg)
进入pod查看情况
![exec pod](https://tva1.sinaimg.cn/large/006y8mN6gy1g8cu9hb48qj30u0092abz.jpg)


#### 删除pv
删除pod，pv和pvc不会被删除，nfs存储的数据不会被删除。
![del pod ](https://tva1.sinaimg.cn/large/006y8mN6gy1g8cub06m8qj30hd03iq3d.jpg)
继续删除pvc，pv将被释放，处于 Available 可用状态，并且nfs存储中的数据被删除。
![del pvc ](https://tva1.sinaimg.cn/large/006y8mN6gy1g8cucndzf7j30us05175e.jpg)
继续删除pv
![del pv](https://tva1.sinaimg.cn/large/006y8mN6gy1g8cud8vkzpj30gf026dg2.jpg)





