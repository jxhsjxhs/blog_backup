---
title: coredns添加自定义DNS解析记录
date: 2020-01-20 15:44:16
tags:
---

coredns 自带 hosts 插件， 允许像配置 hosts 一样配置自定义 DNS 解析，修改 `kube-system` 中 `configMap` 的 `coredns` 添加如下设置即可。

```
    hosts {
        172.21.91.28 cache.redis
        172.21.91.28 persistent.redis
          
        fallthrough
    }
```
修改后文件如下（根据kubernetes 安装方式不同，可能有些许差别）
```
.:53 {
    errors
    health
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       upstream
       fallthrough in-addr.arpa ip6.arpa
    }
    hosts {
        172.21.91.28 cache.redis
        172.21.91.28 persistent.redis
          
        fallthrough
    }
    prometheus :9153
    proxy . /etc/resolv.conf
    cache 30
    loop
    reload
    loadbalance
}
```

## 修改实践
### 找到kube-system命名空间的名称为coredns的configmap
```
» kubectl get configmap coredns -n kube-system                                                                     yjzeng@yjzeng-ubuntu
NAME      DATA   AGE
coredns   1      9d
------------------------------------------------------------------------------------------------------------------------------------------
~ »   
```


### 编辑这个configmap

```
~ » kubectl edit configmap coredns -n kube-system
```

### 编辑为以下内容(添加了hosts块)：

```
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          upstream
          fallthrough in-addr.arpa ip6.arpa
          ttl 30
        }
        hosts {
            10.0.0.22 cos6-data1.test.alltest.com
            10.0.0.23 cos6-data2.test.alltest.com
            10.0.0.24 cos6-data3.test.alltest.com
            10.0.0.25 cos6-data4.test.alltest.com
            10.0.0.26 cos6-data5.test.alltest.com
            10.0.0.41 cos6-datanode6.test.alltest.com
            10.0.0.42 cos6-datanode7.test.alltest.com
            10.0.0.43 cos6-datanode8.test.alltest.com
            10.0.0.44 cos6-datanode9.test.alltest.com
        }
        prometheus :9153
        forward . "/etc/resolv.conf"
        cache 30
        loop
        reload
        loadbalance
    }
kind: ConfigMap
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"Corefile":".:53 {\n    errors\n    health\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n      pods insecure\n      upstream\n      fallthrough in-addr.arpa ip6.arpa\n      ttl 30\n    }\n    prometheus :9153\n    forward . \"/etc/resolv.conf\"\n    cache 30\n    loop\n    reload\n    loadbalance\n}\n"},"kind":"ConfigMap","metadata":{"annotations":{},"labels":{"addonmanager.kubernetes.io/mode":"EnsureExists"},"name":"coredns","namespace":"kube-system"}}
  creationTimestamp: "2019-08-19T09:14:15Z"
  labels:
    addonmanager.kubernetes.io/mode: EnsureExists
  name: coredns
  namespace: kube-system
  resourceVersion: "3231349"
  selfLink: /api/v1/namespaces/kube-system/configmaps/coredns
  uid: b791c47f-c261-11e9-b426-525400116042

```

### 重启coredns：
```
~ » kubectl scale deployment coredns -n kube-system --replicas=0
deployment.extensions/coredns scaled

~ » kubectl scale deployment coredns -n kube-system --replicas=2                                                     yjzeng@yjzeng-ubuntu
deployment.extensions/coredns scaled
```

### 测试，进入任意一个具有ping命令的pod中，ping自己插入的域名，能通就说明已经生效了。