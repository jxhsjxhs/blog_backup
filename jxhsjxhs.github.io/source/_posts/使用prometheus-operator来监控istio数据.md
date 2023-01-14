---
title: 使用prometheus-operator来监控istio数据
date: 2020-06-18 17:51:10
tags: prometheus
---

其实默认安装完istio是会带一个promethes的。但是如果都用那个prometheus局限性比较大  还是用先进的prometheus-operator来监控istio。

### 安装prometheus-operator

```
git clone https://github.com/coreos/kube-prometheus.git ; cd kube-prometheus
kubectl create -f manifests/setup
until kubectl get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done
kubectl create -f manifests/
```

### 查看安装结果
```
[root@master ~]# kubectl  get pod -n monitoring
NAME                                   READY   STATUS    RESTARTS   AGE
alertmanager-main-0                    2/2     Running   0          14d
alertmanager-main-1                    2/2     Running   0          22d
alertmanager-main-2                    2/2     Running   0          22d
grafana-5c55845445-8jvbz               1/1     Running   0          22d
kube-state-metrics-957fd6c75-vxp4k     3/3     Running   0          22d
node-exporter-9hc9q                    2/2     Running   2          22d
node-exporter-d85q9                    2/2     Running   0          22d
node-exporter-fzfhl                    2/2     Running   0          22d
node-exporter-gcm86                    2/2     Running   0          22d
node-exporter-w7xtg                    2/2     Running   0          9d
node-exporter-wvq7b                    2/2     Running   0          22d
prometheus-adapter-5cdcdf9c8d-6c5vq    1/1     Running   0          14d
prometheus-k8s-0                       3/3     Running   1          14d
prometheus-k8s-1                       3/3     Running   1          22d
prometheus-operator-6f98f66b89-4jjff   2/2     Running   0          22d
```

### 给promehteus增加权限监控istio
```
kubectl -n monitoring edit clusterrole prometheus-k8s

rules:
- apiGroups:
  - ""
  resources:
  - nodes/metrics
  - services
  - endpoints
  - pods
  verbs:
  - get
  - list
  - watch
- nonResourceURLs:
  - /metrics
  verbs:
  - get
```

### 安装监控项ServiceMonitor
```
[root@master data]# cat ServiceMonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: istio-monitor
  namespace: monitoring
  labels:
    app: prometheus-istio
spec:
  selector:
    matchLabels:
      app: mixer 
      istio: mixer
  endpoints:
  - port: prometheus 
    interval: 10s    
  namespaceSelector:
    matchNames:
    - istio-system   


[root@master data]# kubectl apply -f ServiceMonitor.yaml
```

### 从promehtues的监控数据中可查看
![](/img/newimg/007S8ZIlgy1gfwxbhgdr3j31ot0u0do8.jpg)
