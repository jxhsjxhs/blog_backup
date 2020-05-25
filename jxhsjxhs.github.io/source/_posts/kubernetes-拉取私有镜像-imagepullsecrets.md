---
title: kubernetes 拉取私有镜像 imagepullsecrets
date: 2020-05-23 15:52:50
tags: k8s
---
###  docker 使用私有仓库

使用docker时,由于私有仓库很多时候没有搭建https的认证证书,访问时需要在本地docker的配置文件中加上允许对次镜像或者对所有镜像的http请求。
```
root@Core:~# cat /etc/docker/dameon.json 
{"insecure-registries": ["0.0.0.0/0"]}

```
![DeepinScreenshot_select-area_20200523193555.png](https://i.loli.net/2020/05/23/b1jExvs8kBHRgYd.png)

然后使用docker login 登录的时候会发现,登录成功以后会在本地生`~/.docker/config.json`的配置文件。
![DeepinScreenshot_select-area_20200523193918.png](https://i.loli.net/2020/05/23/FAWPjmx4Bh9tqvX.png)
该文件会存放登录过的用户的token以及登录仓库的地址


### k8s使用私有仓库

虚假的使用方法

```
在k8s中,想要使用私有仓库而用以上方法是不现实的。如下
1.由于pod是漂移的,不知道下次pod会在哪个节点。
2.并且如果几个部门合作之类的，不止只有一个私有库,在k8s集群中将非常麻烦。
```

---

真实的使用方法

将刚刚生成的`config.json`变成configmap放置到k8s中
```
kubectl create secret generic harborsecret \
    --from-file=.dockerconfigjson=/root/.docker/config.json \
    --type=kubernetes.io/dockerconfigjson
```

查看一下
kubectl get secrets harborsecret 
![DeepinScreenshot_select-area_20200523222238.png](https://i.loli.net/2020/05/23/nV25oGzHJIQkmSa.png)

kubectl get secret harborsecret --output=yaml
![DeepinScreenshot_select-area_20200523222224.png](https://i.loli.net/2020/05/23/WBXF4wsAdVQDR1o.png)

在要部署的deployment中放入此镜像的configmap配置文件

```
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: istio-cosmo
  name: cosmo-bff
spec:
  selector:
    matchLabels:
      app: istio
  template:
    metadata:
      labels:
        app: nginx
    spec:
      imagePullSecrets:
      - name: daocloud-registry
      containers:
      - name: nginx
        image: registry.daocloud.cn/xxx/nginx:264
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: cosmo-conf
          mountPath: /work/config
      volumes:
      - name: cosmo-conf
        configMap:
          name: cosmo-conf
```
这样不管是哪台机器执行下载该镜像的任务都会调用这个config文件。

