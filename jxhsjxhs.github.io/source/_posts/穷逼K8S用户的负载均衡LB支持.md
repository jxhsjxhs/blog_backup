---
title: 穷逼K8S用户的负载均衡LB支持
date: 2020-01-20 16:38:18
tags:
---

### 背景项目
很多公司使用k8s都是私有云方式,在没钱玩NMB的社会.连k8s都会歧视你。 服务的暴露方式只有nodeport、ExternalIP(直接使用主机网络)和ingress。剥夺了LoadBalance模式的权利

### metallb 简介
这里简单介绍下它的实现原理，具体可以参考[metallb官网](https://metallb.universe.tf/)，文档非常简洁、清晰。目前有如下的使用限制：
> Kubernetes v1.9.0版本以上，暂不支持ipvs模式
> 支持网络组件 (flannel/weave/romana), calico 部分支持
> layer2和bgp两种模式，其中bgp模式需要外部网络设备支持bgp协议

metallb主要实现了两个功能：地址分配和对外宣告
> 地址分配：需要向网络管理员申请一段ip地址，如果是layer2模式需要这段地址与node节点地址同个网段（同一个二层）；如果是bgp模式没有这个限制。
> 对外宣告：layer2模式使用arp协议，利用节点的mac额外宣告一个loadbalancer的ip（同mac多ip）；bgp模式下节点利用bgp协议与外部网络设备建立邻居，宣告loadbalancer的地址段给外部网络。

### 演示环境信息
![](https://tva1.sinaimg.cn/large/006tNbRwgy1gb4ghrhg6ij31xo068q9o.jpg)

### 部署过程
注: 因bgp模式需要外部路由器的支持，这里主要选用layer2模式（如需选择bgp模式，相应修改roles/cluster-addon/templates/metallb/bgp.yaml.j2）。

> Metallb 支持 Helm 和 YAML 两种安装方法，这里我们使用第二种：
```
wget https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml
kubectl apply -f metallb.yaml
.
.
.
kubectl get pod -n metallb-system  -o wide

NAME                          READY   STATUS    RESTARTS   AGE   IP               NODE     
controller-67496974d9-wpgw8   1/1     Running   0          75m   100.108.11.251   node2    
speaker-4cscj                 1/1     Running   0          75m   10.6.204.2       node1    
speaker-9s55h                 1/1     Running   0          75m   10.6.204.3       node2    
speaker-kr2bm                 1/1     Running   0          75m   10.6.204.1       master   
```
kubectl get daemonset -n metallb-system

```
NAME      DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR                 
speaker   3         3         3       3            3           beta.kubernetes.io/os=linux  
```

kubectl get deployment -n metallb-system

```
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
controller   1/1     1            1           76m
```

创建config.yaml提供IP池
wget https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/example-layer2-config.yaml
修改ip地址池和集群节点网段相同
```
[centos@k8s-master ~]$ vim example-layer2-config.yaml 

apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 10.6.204.20-10.6.204.22
```

执行yaml文件
kubectl apply -f example-layer2-config.yaml

创建后端应用和服务测试

```
$ wget https://raw.githubusercontent.com/google/metallb/master/manifests/tutorial-2.yaml
$ kubectl apply -f tutorial-2.yaml
```

查看svc对象
```
kubectl get service 

NAME                TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
front-end-service   NodePort       10.101.75.133    <none>        80:31402/TCP     48d
gogs                NodePort       10.104.31.59     <none>        3000:30064/TCP   19d
kubernetes          ClusterIP      10.96.0.1        <none>        443/TCP          54d
nexus3              NodePort       10.98.65.125     <none>        8082:31899/TCP   8h
nginx               LoadBalancer   10.98.137.237    10.6.204.20   80:31909/TCP     28m
nginx-random        NodePort       10.111.254.203   <none>        80:31691/TCP     48d
```

在集群内访问 10.6.204.20:80

```
curl 10.6.204.20

<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```
在集群外部访问
![](https://tva1.sinaimg.cn/large/006tNbRwgy1gb4goj0mqmj31vs0kgn1k.jpg)


