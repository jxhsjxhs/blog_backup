---
title: k8s部署mysql单节点到sotrageclass
date: 2020-05-23 15:26:30
tags: k8s, 中间件, mysql
---

## mysql5.7 单节点部署

> 记录一下方便以后复制粘贴

```
未经过强调说明的话都是以default租户下部署，有存储的话用的都是名为nfs-storage的storageclass.
```
![DeepinScreenshot_select-area_20200523161014.png](https://i.loli.net/2020/05/23/SB1KbhiX8D4HZ6T.png)

首先创建mysql的configmap
```
[root@master conf]# cat mysqld.cnf 

[mysqld]
pid-file	= /var/run/mysqld/mysqld.pid
socket		= /var/run/mysqld/mysqld.sock
datadir		= /var/lib/mysql
#log-error	= /var/log/mysql/error.log
# By default we only accept connections from localhost
#bind-address	= 127.0.0.1
# Disabling symbolic-links is recommended to prevent assorted security risks
symbolic-links=0
sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION
```
注意  因为mysql5.7默认关闭了`group by`相关命令 需要在配置文件中加上sql_mode打开。

```
kubectl create configmap mysql-config  --from-file=mysql.cnf 
```
![DeepinScreenshot_select-area_20200523161014.png](https://i.loli.net/2020/05/23/KfmWpMvNdBbunkC.png)


查看创建的configmap,接下来创建使用storageclass的deloyment



```
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: mysqldata
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 20G
  storageClassName: nfs-storage
---

apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: mysql57
  name: mysql57
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql57
  template:
    metadata:
      labels:
        app: mysql57
    spec:
      containers:
      - env:
        - name: MYSQL_ROOT_PASSWORD
          value: "2020520.pst"
        - name: MYSQL_USER
          value: "daocloud"
        - name: MYSQL_PASSWORD
          value: "daocloud@123456"
        image: "mysql:5.7"
        name: mysql57
        ports:
        - containerPort: 3306
          protocol: TCP
          name: http
        volumeMounts:
        - name: mysqldata
          mountPath: "/var/lib/mysql"
          readOnly: false
          subPath: mysql57
        - name: mysql-config
          mountPath: /etc/mysql/mysql.conf.d
      volumes:
      - name: mysqldata
        persistentVolumeClaim:
          claimName: mysqldata
      - name: mysql-config
        configMap:
          name: mysql-config

```
查看创建的服务以及pvc
![DeepinScreenshot_select-area_20200523161856.png](https://i.loli.net/2020/05/23/u3LmVFZPGSylkDT.png)


当然如果外部用的话也可以用service或者ingress映射出来.
```
apiVersion: v1
kind: Service
metadata:
  name: mysql57
spec:
  selector:
    app: mysql57
  ports:
    - name: mysql3306
      port: 3306
      protocol: TCP
      targetPort: 3306
      nodePort: 30881
  type: NodePort

```
![DeepinScreenshot_select-area_20200523162141.png](https://i.loli.net/2020/05/23/GLTzpdcrSgn7iv3.png)