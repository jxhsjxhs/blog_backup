---
title: 'kubernetes笔记: HostAliases'
date: 2020-01-03 18:07:09
tags:
---

k8s上不同服务之间可以通过service的域名来互相访问。域名的解析是一般是通过在集群中的kube-dns（主要是dnsmasq）或者coredns完成的。k8s的dns也可以向上级联dns服务器。

有的时候，我们希望给运行在k8s上的Pod增加一些域名的解析（例如宿主机的主机名），但又不想对dns模块动太多，有没有什么比较方便的办法呢？
方法如下:
>容器挂载宿主机/etc/hosts 并设置亲和性。让此pod只在该主机上
>用k8s特性 .spec.hostAliases。hostAliases字段
>更改集群中的coredns的记录

此篇主要讲解hostAliases方法。

## 使用 HostAliases 向 Pod /etc/hosts 文件添加条目
当 DNS 配置以及其它选项不合理的时候，通过向 Pod 的 /etc/hosts 文件中添加条目，可以在 Pod 级别覆盖对主机名的解析。在 1.7 版本，用户可以通过 PodSpec 的 HostAliases 字段来添加这些自定义的条目。

建议通过使用 HostAliases 来进行修改，因为该文件由 Kubelet 管理，并且可以在 Pod 创建/重启过程中被重写。

### 默认 hosts 文件内容
让我们从一个 Nginx Pod 开始，给该 Pod 分配一个 IP：
```
kubectl run nginx --image nginx --generator=run-pod/v1
pod/nginx created
```

检查Pod IP：
```
kubectl get pods --output=wide

NAME     READY     STATUS    RESTARTS   AGE    IP           NODE
nginx    1/1       Running   0          13s    10.200.0.4   worker0
```
主机文件的内容如下所示：
```
kubectl exec nginx -- cat /etc/hosts

# Kubernetes-managed hosts file.
127.0.0.1	localhost
::1	localhost ip6-localhost ip6-loopback
fe00::0	ip6-localnet
fe00::0	ip6-mcastprefix
fe00::1	ip6-allnodes
fe00::2	ip6-allrouters
10.200.0.4	nginx
```

默认，hosts 文件只包含 ipv4 和 ipv6 的样板内容，像 localhost 和主机名称。


### 通过 HostAliases 增加额外的条目
除了默认的样板内容，我们可以向 hosts 文件添加额外的条目，将 foo.local、 bar.local 解析为127.0.0.1， 将 foo.remote、 bar.remote 解析为 10.1.2.3，我们可以在 .spec.hostAliases 下为 Pod 添加 HostAliases。


```
service/networking/hostaliases-pod.yaml 

apiVersion: v1
kind: Pod
metadata:
  name: hostaliases-pod
spec:
  restartPolicy: Never
  hostAliases:
  - ip: "127.0.0.1"
    hostnames:
    - "foo.local"
    - "bar.local"
  - ip: "10.1.2.3"
    hostnames:
    - "foo.remote"
    - "bar.remote"
  containers:
  - name: cat-hosts
    image: busybox
    command:
    - cat
    args:
    - "/etc/hosts"

```
可以使用以下命令启动此Pod：
```
kubectl apply -f hostaliases-pod.yaml

pod/hostaliases-pod created
```
检查Pod IP 和状态：
```
kubectl get pod --output=wide

NAME                           READY     STATUS      RESTARTS   AGE       IP              NODE
hostaliases-pod                0/1       Completed   0          6s        10.200.0.5      worker0
```
hosts 文件的内容看起来类似如下这样：

```
kubectl logs hostaliases-pod

# Kubernetes-managed hosts file.
127.0.0.1	localhost
::1	localhost ip6-localhost ip6-loopback
fe00::0	ip6-localnet
fe00::0	ip6-mcastprefix
fe00::1	ip6-allnodes
fe00::2	ip6-allrouters
10.200.0.5	hostaliases-pod

# Entries added by HostAliases.
127.0.0.1	foo.local	bar.local
10.1.2.3	foo.remote	bar.remote
```

在最下面额外添加了一些条目
### 为什么 Kubelet 管理 hosts文件？


kubelet 管理 Pod 中每个容器的 hosts 文件，避免 Docker 在容器已经启动之后去 修改 该文件。

因为该文件是托管性质的文件，无论容器重启或 Pod 重新调度，用户修改该 hosts 文件的任何内容，都会在 Kubelet 重新安装后被覆盖。因此，不建议修改该文件的内容。


