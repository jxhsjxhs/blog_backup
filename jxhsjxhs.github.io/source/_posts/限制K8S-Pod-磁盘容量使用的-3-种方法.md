---
title: 限制K8S Pod 磁盘容量使用的 3 种方法
date: 2021-10-31 18:49:11
tags:
---

### Pod 如何使用磁盘
容器在运行期间会产生临时文件、日志。如果没有任何配额机制，则某些容器可能很快将磁盘写满，影响宿主机内核和所有应用。容器的临时存储，例如 emptyDir，位于目录/var/lib/kubelet/pods 下：


```
/var/lib/kubelet/pods/
└── ac0810f5-a1ce-11ea-9caf-00e04c687e45  # POD_ID
    ├── containers
    │   ├── istio-init
    │   │   └── 32390fd7
    │   ├── istio-proxy
    │   │   └── 70ed81da
    │   └── zookeeper
    │       └── e9e21e59
    ├── etc-hosts          # 命名空间的Host文件
    └── volumes            # Pod的卷
        ├── kubernetes.io~configmap  # ConfigMap类型的卷
        │   └── istiod-ca-cert
        │       └── root-cert.pem -> ..data/root-cert.pem
        ├── kubernetes.io~downward-api
        │   └── istio-podinfo
        │       ├── annotations -> ..data/annotations
        │       └── labels -> ..data/labels
        ├── kubernetes.io~empty-dir # Empty类型的卷
        │   ├── istio-data
        │   └── istio-envoy
        │       ├── envoy-rev0.json
        │       └── SDS
        ├── kubernetes.io~rbd       # RBD卷
        │   └── pvc-644a7e30-845e-11ea-a4e1-70e24c686d29 # /dev/rbd0挂载到这个挂载点
        ├── kubernetes.io~csi       # CSI卷
        └── kubernetes.io~secret    # Secret类型的卷
            └── default-token-jp4n8
                ├── ca.crt -> ..data/ca.crt
                ├── namespace -> ..data/namespace
                └── token -> ..data/token
```

持久卷的挂载点也位于/var/lib/kubelet/pods 下，但是不会导致存储空间的消耗。容器的日志，存放在/var/log/pods 目录下。使用 Docker 时，容器的 rootfs 位于/var/lib/docker 下，具体位置取决于存储驱动。


### Pod 驱逐机制


#### 磁盘容量不足触发的驱逐

具体细节参考：/kubernetes-study-note#out-of-resource[1]。当不可压缩资源（内存、磁盘）不足时，节点上的 Kubelet 会尝试驱逐掉某些 Pod，以释放资源，防止整个系统受到影响。其中，磁盘资源不足的信号来源有两个：imagefs：容器运行时用作存储镜像、可写层的文件系统 nodefs：Kubelet 用作卷、守护进程日志的文件系统 当 imagefs 用量到达驱逐阈值，Kubelet 会删除所有未使用的镜像，释放空间。当 nodefs 用量到达阈值，Kubelet 会选择性的驱逐 Pod（及其容器）来释放空间。

#### 本地临时存储触发的驱逐

较新版本的 K8S 支持设置每个 Pod 可以使用的临时存储的 request/limit，驱逐行为可以更具有针对性。如果 Pod 使用了超过限制的本地临时存储，Kubelet 将设置驱逐信号，触发 Pod 驱逐流程：对于容器级别的隔离，如果一个容器的可写层、日志占用磁盘超过限制，则 Kubelet 标记 Pod 为待驱逐 对于 Pod 级别的隔离，Pod 总用量限制，是每个容器限制之和。如果各容器用量之和+Pod 的 emptyDir 卷超过 Pod 总用量限制，标记 Pod 为待驱逐



### 从编排层限制

从 K8S 1.8 开始，支持本地临时存储（local ephemeral storage），ephemeral 的意思是，数据的持久性（durability）不做保证。临时存储可能 Backed by 本地 Attach 的可写设备，或者内存。Pod 可以使用本地临时存储来作为暂存空间，或者存放缓存、日志。Kubelet 可以利用本地临时存储，将 emptyDir 卷挂载给容器。Kubelet 也使用本地临时存储来保存节点级别的容器日志、容器镜像、容器的可写层。Kubelet 会将日志写入到你配置好的日志目录，默认 /var/log。其它文件默认都写入到 /var/lib/kubelet。在典型情况下，这两个目录可能都位于宿主机的 rootfs 之下。Kubernetes 支持跟踪、保留/限制 Pod 能够使用的本地临时存储的总量。
##### 限制 Pod 用量

打开特性开关：LocalStorageCapacityIsolation，可以限制每个 Pod 能够使用的临时存储的总量。注意：以内存为媒介（tmpfs）的 emptyDir，其用量计入容器内存消耗，而非本地临时存储消耗。使用类似限制内存、CPU 用量的方式，限制本地临时存储用量：


```
spec.containers[].resources.limits.ephemeral-storage
spec.containers[].resources.requests.ephemeral-storage
```


单位可以是 E, P, T, G, M, K，或者 Ei, Pi, Ti, Gi, Mi, Ki（1024）。下面这个例子，Pod 具有两个容器，每个容器最多使用 4GiB 的本地临时存储：

```
apiVersion: v1
kind: Pod
metadata:
  name: frontend
spec:
  containers:
  - name: db
    image: mysql
    env:
    - name: MYSQL_ROOT_PASSWORD
      value: "password"
    resources:
      requests:
        ephemeral-storage: "2Gi"
      limits:
        ephemeral-storage: "4Gi"
  - name: wp
    image: wordpress
    resources:
      requests:
        ephemeral-storage: "2Gi"
      limits:
        ephemeral-storage: "4Gi"
```

#### 对 Pod 用量的监控
##### 不监控

如果禁用 Kubelet 对本地临时存储的监控，则 Pod 超过 limit 限制后不会被驱逐。但是，如果磁盘整体上容量太低，节点会被打上污点，所有不能容忍此污点的 Pod 都会被驱逐。
##### 周期性扫描

Kubelet 可以执行周期性的扫描，检查 emptyDir 卷、容器日志目录、可写容器层，然后计算 Pod/容器使用了多少磁盘。这个模式下有个问题需要注意，Kubelet 不会跟踪已删除文件的描述符。也就是说，如果你创建一个文件，打开文件，写入 1GB，然后删除文件，这种情况下 inode 仍然存在（直到你关闭文件），空间仍然被占用，但是 Kubelet 却没有算这 1GB.
##### Project Quotas

此特性在 1.15+处于 Alpha 状态。Project quotas 是 Linux 操作系统级别的特性，用于在目录级别限制磁盘用量。只有本地临时存储（例如 emptyDir）的后备（Backing）文件系统支持 Project quotas，才可以使用该特性。XFS、ext4 都支持 Project quotas。K8S 将占用从 1048576 开始的 Project ID，占用中的 ID 注册在/etc/projects、/etc/projid 文件中。如果系统中其它进程占用 Project ID，则也必须在这两个文件中注册，这样 K8S 才会改用其它 ID。Quotas 比周期性扫描快，而且更加精准。当一个目录被分配到一个 Project 中后，该目录中创建的任何文件，都是在 Project 中创建的。为了统计用量，内核只需要跟踪 Project 中创建了多少 block 就可以了。如果文件被创建、然后删除，但是它的文件描述符仍然处于打开状态，这种情况下，它仍然消耗空间，不会出现周期性扫描的那种漏统计的问题。要启用 Project Quotas，你需要：
开启 Kubelet 特性开关：LocalStorageCapacityIsolationFSQuotaMonitoring
确保文件系统支持 Project quotas：
XFS 文件系统默认支持，不需要操作
ext4 文件系统，你需要在未挂载之前，启用：
```
$ sudo tune2fs -O project -Q prjquota /dev/vda
```
确保文件系统挂载时，启用了 Project quotas。使用挂载选项 prjquota


#### inode 耗尽问题

有的时候，我们会发现磁盘写入时会报磁盘满，但是 df 查看容量并没有 100%使用，此时可能只是因为 inode 耗尽造成的。当前 k8s 并不支持对 Pod 的临时存储设置 inode 的 limits/requests。但是，如果 node 进入了 inode 紧缺的状态，kubelet 会将 node 设置为 under pressure，不再接收新的 Pod 请求。



### 从容器引擎限制
Docker 提供了配置项 --storage-opt，可以限制容器占用磁盘空间的大小，此大小影响镜像和容器文件系统，默认 10G。你也可以在 /etc/docker/daemon.json 中修改此配置项：

```
{
    "storage-driver": "devicemapper",
    "storage-opts": [
        // devicemapper
        "dm.basesize=20G",
        // overlay2
        "overlay2.size=20G",
    ]
}
```
但是这种配置无法影响那些挂载的卷，例如 emptyDir。



### 从系统层限制

你可以使用 Linux 系统提供的任何能够限制磁盘用量的机制，为了和 K8S 对接，需要开发 Flexvolume 或 CSI 驱动。
#### 磁盘配额

前文已经介绍过，K8S 目前支持基于 Project quotas 来统计 Pod 的磁盘用量。这里简单总结一下 Linux 磁盘配额机制。
#### 配额目标

Linux 系统支持以下几种角度的配额：
在文件系统级别，限制群组能够使用的最大磁盘额度
在文件系统级别，限制单个用户能够使用的最大磁盘额度
限制某个目录（directory, project）能够占用的最大磁盘额度
前面 2 种配额，现代 Linux 都支持，不需要前提条件。你甚至可以在一个虚拟的文件系统上进行配额：

```
# 写一个空白文件
$ dd if=/dev/zero of=/path/to/the/file bs=4096 count=4096
# 格式化
...
# 挂载为虚拟文件系统
$ mount -o loop,rw,usrquota,grpquota /path/to/the/file /path/of/mount/point
# 进行配额设置...
```

第 3 种需要较新的文件系统，例如 XFS、ext4fs。
#### 配额角度

配额可以针对 Block 用量进行，也可以针对 inode 用量进行。配额可以具有软限制、硬限制。超过软限制后，仍然可以正常使用，但是登陆后会收到警告，在 grace time 倒计时完毕之前，用量低于软限制后，一切恢复正常。如果 grace time 到期仍然没做清理，则无法创建新文件。
#### 统计用量

启用配额，内核自然需要统计用量。管理员要查询用量，可以使用 xfs_quota 这样的命令，比 du 这种遍历文件计算的方式要快得多。
#### 启用配额

在保证底层文件系统支持之后，你需要修改挂载选项来启用配额：
uquota/usrquota/quota：针对用户设置配额
gquota/grpquota：针对群组设置配额
pquota/prjquota：针对目录设置配额
#### LVM

使用 LVM 你可以任意创建具有尺寸限制的逻辑卷，把这些逻辑卷挂载给 Pod 即可：


```

volumes:
- flexVolume:
    # 编写的flexVolume驱动放到
    # /usr/libexec/kubernetes/kubelet-plugins/volume/exec/kubernetes.io~lvm/lvm
    driver: kubernetes.io/lvm
    fsType: ext4
    options:
      size: 30Gi
      volumegroup: docker
  name: mnt
volumeMounts:
  - mountPath: /mnt
    name: mnt
```
这需要修改编排方式，不使用 emptyDir 这种本地临时存储，还需要处理好逻辑卷清理工作。
