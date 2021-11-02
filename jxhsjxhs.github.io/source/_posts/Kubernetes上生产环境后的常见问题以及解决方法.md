---
title: Kubernetes上生产环境后的常见问题以及解决方法
date: 2021-10-31 18:40:04
tags:
---
随着微服务的不断推进，使用 k8s 集群越来越多，越来越深入，随之而来会遇到一系列的问题，本文向大家介绍实际使用 k8s 遇到的一些问题以及解决方法。
### 问题一:  修复 K8S 内存泄露问题
> 问题描述
A现象->  当 k8s 集群运行日久以后，有的 node 无法再新建 pod，并且出现如下错误，当重启服务器之后，才可以恢复正常使用。查看 pod 状态的时候会出现以下报错。

```
applying cgroup … caused: mkdir …no space left on device
```

或者在 describe pod 的时候出现 cannot allocate memory。

这时候你的 k8s 集群可能就存在内存泄露的问题了，当创建的 pod 越多的时候内存会泄露的越多，越快。

B现象-> 具体查看是否存在内存泄露

```
$ cat /sys/fs/cgroup/memory/kubepods/memory.kmem.slabinfo
```

当出现 cat: /sys/fs/cgroup/memory/kubepods/memory.kmem.slabinfo: Input/output error 则说明不存在内存泄露的情况 如果存在内存泄露会出现


```
slabinfo - version: 2.1
# name            <active_objs> <num_objs> <objsize> <objperslab> <pagesperslab> : tunables <limit> <batchcount> <sharedfactor> : slabdata <active_slabs> <num_slabs> <sharedavail>
```

> 解决方案

1. 解决方法思路：关闭 runc 和 kubelet 的 kmem，因为升级内核的方案改动较大，此处不采用。

2. kmem 导致内存泄露的原因：

内核对于每个 cgroup 子系统的的条目数是有限制的，限制的大小定义在 kernel/cgroup.c #L139，当正常在 cgroup 创建一个 group 的目录时，条目数就加 1。我们遇到的情况就是因为开启了 kmem accounting 功能，虽然 cgroup 的目录删除了，但是条目没有回收。这样后面就无法创建 65535 个 cgroup 了。也就是说，在当前内核版本下，开启了 kmem accounting 功能，会导致 memory cgroup 的条目泄漏无法回收。


### 问题二：k8s 证书过期问题的两种处理方法

> 前情提要
公司测试环境的 k8s 集群使用已经很长时间了,突然有一天开发联系我说 k8s 集群无法访问，开始以为是测试环境的机器磁盘空间不够了，导致组件异常或者把开发使用的镜像自动清理掉了，但是当登上机器去查验的时候发现不是这个原因。当时觉得也很疑惑。因为开发环境使用人数较少，不应该会出问题，所以就去查验 log 的相关报错信息。

> 问题现象
出现 k8s api 无法调取的现象，使用 kubectl 命令获取资源均返回如下报错:

```
$ Unable to connect to the server: x509: certificate has expired or is not yet valid
```
经网上搜索之后发现应该是 k8s 集群的证书过期了，使用命令排查证书的过期时间
```
$ kubeadm alpha certs check-expiration
```
发现确实是证书过期了

相关介绍以及问题解决
因为我们是使用 kubeadm 部署的 k8s 集群，所以更新起证书也是比较方便的，默认的证书时间有效期是一年，我们集群的 k8s 版本是 1.15.3 版本是可以使用以下命令来更新证书的，但是一年之后还是会到期，这样就很麻烦，所以我们需要了解一下 k8s 的证书，然后我们来生成一个时间很长的证书，这样我们就可以不用去总更新证书了。

```
$ kubeadm alpha certs renew all --config=kubeadm.yaml
$ systemctl restart kubelet
$ kubeadm init phase kubeconfig all --config kubeadm.yaml
# 然后将生成的配置文件替换,重启 kube-apiserver、kube-controller、kube-scheduler、etcd 这4个容器即可
另外 kubeadm 会在控制面板升级的时候自动更新所有证书，所以使用 kubeadm 搭建的集群最佳的做法是经常升级集群，这样可以确保你的集群保持最新状态并保持合理的安全性。但是对于实际的生产环境我们可能并不会去频繁的升级集群，所以这个时候我们就需要去手动更新证书。
```

下面我们通过调用 k8s 的 api 来实现更新一个 10 年的证书

首先在 /etc/kubernetes/manifests/kube-controller-manager.yaml 文件加入配置
```
spec:
  containers:
  - command:
    - kube-controller-manager
    # 设置证书有效期为 10年
    - --experimental-cluster-signing-duration=87600h
    - --client-ca-file=/etc/kubernetes/pki/ca.crt
```

修改完成后 kube-controller-manager 会自动重启生效。然后我们需要使用下面的命令为 Kubernetes 证书 API 创建一个证书签名请求。如果您设置例如 cert-manager 等外部签名者，则会自动批准证书签名请求（CSRs）。否者，您必须使用 kubectl certificate 命令手动批准证书。以下 kubeadm 命令输出要批准的证书名称，然后等待批准发生：
```
# 需要将全部 pending 的证书全部批准
$ kubeadm alpha certs renew all --use-api --config kubeadm.yaml &
```
我们还不能直接重启控制面板的几个组件，这是因为使用 kubeadm 安装的集群对应的 etcd 默认是使用的 /etc/kubernetes/pki/etcd/ca.crt 这个证书进行前面的，而上面我们用命令 kubectl certificate approve 批准过后的证书是使用的默认的 /etc/kubernetes/pki/ca.crt 证书进行签发的，所以我们需要替换 etcd 中的 ca 机构证书:
```
# 先拷贝静态 Pod 资源清单
$ cp -r /etc/kubernetes/manifests/ /etc/kubernetes/manifests.bak
$ vi /etc/kubernetes/manifests/etcd.yaml
......
spec:
  containers:
  - command:
    - etcd
    # 修改为 CA 文件
    - --peer-trusted-ca-file=/etc/kubernetes/pki/ca.crt
    - --trusted-ca-file=/etc/kubernetes/pki/ca.crt
......
    volumeMounts:
    - mountPath: /var/lib/etcd
      name: etcd-data
    - mountPath: /etc/kubernetes/pki  # 更改证书目录
      name: etcd-certs
  volumes:
  - hostPath:
      path: /etc/kubernetes/pki  # 将 pki 目录挂载到 etcd 中去
      type: DirectoryOrCreate
    name: etcd-certs
  - hostPath:
      path: /var/lib/etcd
      type: DirectoryOrCreate
    name: etcd-data
......
```
由于 kube-apiserver 要连接 etcd 集群，所以也需要重新修改对应的 etcd ca 文件：
```
$ vi /etc/kubernetes/manifests/kube-apiserver.yaml
......
spec:
  containers:
  - command:
    - kube-apiserver
    # 将etcd ca文件修改为默认的ca.crt文件
    - --etcd-cafile=/etc/kubernetes/pki/ca.crt
......
```
除此之外还需要替换 requestheader-client-ca-file 文件，默认是 /etc/kubernetes/pki/front-proxy-ca.crt 文件，现在也需要替换成默认的 CA 文件，否则使用聚合 API，比如安装了 metrics-server 后执行 kubectl top 命令就会报错：
```
$ cp /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/front-proxy-ca.crt
$ cp /etc/kubernetes/pki/ca.key /etc/kubernetes/pki/front-proxy-ca.key
```

这样我们就得到了一个 10 年证书的 k8s 集群，还可以通过重新编译 kubeadm 来实现一个 10 年证书的，这个我没有尝试，不过在初始化集群的时候也是一个方法。