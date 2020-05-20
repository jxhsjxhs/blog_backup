---
title: 利用动态存储卷StorageClass使用nfs
date: 2019-10-27 02:36:56
categories: 容器
tags: k8s,nfs
---

之前我们部署了PV 和 PVC 的使用方法，但是前面的 PV 都是静态的，什么意思？就是我要使用的一个 PVC 的话就必须手动去创建一个 PV，我们也说过这种方式在很大程度上并不能满足我们的需求，比如我们有一个应用需要对存储的并发度要求比较高，而另外一个应用对读写速度又要求比较高，特别是对于 StatefulSet 类型的应用简单的来使用静态的 PV 就很不合适了，这种情况下我们就需要用到动态 PV，也就是我们今天要讲解的 StorageClass。

我们这里演示一下NFS的动态PV创建

### 创建

要使用 StorageClass，我们就得安装对应的自动配置程序，比如我们这里存储后端使用的是 nfs，那么我们就需要使用到一个 nfs-client 的自动配置程序，我们也叫它 Provisioner，这个程序使用我们已经配置好的 nfs 服务器，来自动创建持久卷，也就是自动帮我们创建 PV。

自动创建的 PV 以${namespace}-${pvcName}-${pvName}这样的命名格式创建在 NFS 服务器上的共享数据目录中
而当这个 PV 被回收后会以archieved-${namespace}-${pvcName}-${pvName}这样的命名格式存在 NFS 服务器上。

> kubernetes本身支持的动态PV创建不包括nfs，所以需要使用额外插件实现。nfs-client

--- 

第一步：配置 Deployment，将里面的对应的参数替换成我们自己的 nfs 配置（nfs-client.yaml）
第二步：将环境变量 NFS_SERVER 和 NFS_PATH 替换，当然也包括下面的 nfs 配置，我们可以看到我们这里使用了一个名为 nfs-client-provisioner 的serviceAccount，所以我们也需要创建一个 sa，然后绑定上对应的权限：（nfs-client-sa.yaml）
第三步：nfs-client 的 Deployment 声明完成后，我们就可以来创建一个StorageClass对象了：（nfs-client-class.yaml）

> 我们整合三个配置，如下

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
  namespace: kube-system
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["list", "watch", "create", "update", "patch"]

---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io

---
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: nfs-client-provisioner
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: nfs-client-provisioner
  replicas: 1
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccount: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: jmgao1983/nfs-client-provisioner
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          resources:
            requests:
              cpu: "0.4"
              memory: "1Gi"
            limits:
              cpu: "1"
              memory: "1Gi"
          env:
            - name: PROVISIONER_NAME
              value: fuseim.pri/ifs2
            - name: NFS_SERVER
              value: 10.6.204.1
            - name: NFS_PATH
              value: /data/nfs
      volumes:
        - name: nfs-client-root
          nfs:
            server: 10.6.204.1
            path: /data/nfs

---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-storage
provisioner: fuseim.pri/ifs2
```

### 使用
查看创建好的storageclass
![storageclass](https://tva1.sinaimg.cn/large/006tNbRwgy1ga9zbr3jiwj30ls050js9.jpg)

创建pvc,查看是否自动创建相应的pv
```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc001
  namespace: default
spec:
  storageClassName: nfs-storage  # 匹配pvc名
  accessModes:  
  - ReadWriteMany
  resources: 
    requests:
      storage: 500Mi  # 定义要求有多大空间
```

执行可以发现，创建pvc请求以后，pvc已经绑定上自动创建的pv中。
![bond](https://tva1.sinaimg.cn/large/006tNbRwgy1ga9zf0kl7aj31yw0deqjn.jpg)