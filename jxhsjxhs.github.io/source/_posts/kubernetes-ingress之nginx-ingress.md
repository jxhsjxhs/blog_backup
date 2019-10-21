---
title: kubernetes ingress之nginx-ingress
date: 2019-07-29 15:56:12
categories: 容器
tags: k8s
---

#### ingress 介绍

在 k8s 中 service 就有可以让 pod 的工作端口暴露出来的三种方式

ClusterIP、NodePort 与 LoadBalance，这几种方式都是在 service 的维度提供的，service 的作用体现在两个方面，对集群内部，它不断跟踪 pod 的变化，更新 endpoint 中对应 pod 的对象，提供了 ip 不断变化的 pod 的服务发现机制，对集群外部，他类似负载均衡器，可以在集群内外部对 pod 进行访问。但是，单独用 service 暴露服务的方式，在实际生产环境中不太合适：

> 1 . ClusterIP 的方式只能在集群内部访问。
> 2 . NodePort 方式的话，测试环境使用还行，当有几十上百的服务在集群中运行时，NodePort 的端口管理是灾难。
> 3 . LoadBalance 方式受限于云平台，且通常在云平台部署 ELB 还需要额外的费用。

所幸 k8s 还提供了一种集群维度暴露服务的方式，也就是 ingress。ingress 可以简单理解为 service 的 service，他通过独立的 ingress 对象来制定请求转发的规则，把请求路由到一个或多个 service 中。这样就把服务与请求规则解耦了，可以从业务维度统一考虑业务的暴露，而不用为每个 service 单独考虑。

![ingress工作流](https://tva1.sinaimg.cn/large/006y8mN6gy1g8655gjrg7j30if0c50to.jpg)

截至目前，nginx-ingress 已经能够完成 7/4 层的代理功能 (本文基于目前最新版本 ingress-nginx0.25.0)

#### ingress 与 ingress-controller 组件介绍

要理解 ingress，需要区分两个概念，ingress 和 ingress-controller：

- ingress 对象：
  指的是 k8s 中的一个 api 对象，一般用 yaml 配置。作用是定义请求如何转发到 service 的规则，可以理解为配置模板。
- ingress-controller：
  具体实现反向代理及负载均衡的程序，对 ingress 定义的规则进行解析，根据配置的规则来实现请求转发。

简单来说，ingress-controller 才是负责具体转发的组件，通过各种方式将它暴露在集群入口，外部对集群的请求流量会先到 ingress-controller，而 ingress 对象是用来告诉 ingress-controller 该如何转发请求，比如哪些域名哪些 path 要转发到哪些服务等等。

---

ingress-controller

ingress-controller 并不是 k8s 自带的组件，实际上 ingress-controller 只是一个统称，用户可以选择不同的 ingress-controller 实现，目前，由 k8s 维护的 ingress-controller 只有 google 云的 GCE 与 ingress-nginx 两个，其他还有很多第三方维护的 ingress-controller，具体可以参考[官方文档](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/#additional-controllers)。但是不管哪一种 ingress-controller，实现的机制都大同小异，只是在具体配置上有差异。一般来说，ingress-controller 的形式都是一个 pod，里面跑着 daemon 程序和反向代理程序。daemon 负责不断监控集群的变化，根据 ingress 对象生成配置并应用新配置到反向代理，比如 nginx-ingress 就是动态生成 nginx 配置，动态更新 upstream，并在需要的时候 reload 程序应用新配置。为了方便，后面的例子都以 k8s 官方维护的 nginx-ingress 为例。

---

ingress

ingress 是一个 API 对象，和其他对象一样，通过 yaml 文件来配置。ingress 通过 http 或 https 暴露集群内部 service，给 service 提供外部 URL、负载均衡、SSL/TLS 能力以及基于 host 的方向代理。ingress 要依靠 ingress-controller 来具体实现以上功能。

#### ingress 工作原理

![工作原理](https://tva1.sinaimg.cn/large/006y8mN6gy1g8655gep4oj30o10bu418.jpg)

Nginx `注意 新版本已经将nginx替换为OpenResty` 对后端运行的服务（Service1、Service2）提供反向代理，在配置文件中配置了域名与后端服务 Endpoints 的对应关系。客户端通过使用 DNS 服务或者直接配置本地的 hosts 文件，将域名都映射到 Nginx 代理服务器。当客户端访问 service1.com 时，浏览器会把包含域名的请求发送给 nginx 服务器，nginx 服务器根据传来的域名，选择对应的 Service，这里就是选择 Service 1 后端服务，然后根据一定的负载均衡策略，选择 Service1 中的某个容器接收来自客户端的请求并作出响应。过程很简单，nginx 在整个过程中仿佛是一台根据域名进行请求转发的“路由器”，这也就是 7 层代理的整体工作流程了！

> 1.ingress controller 通过和 kubernetes api 交互，动态的去感知集群中 ingress 规则变化.
>
> 2.然后读取它，按照自定义的规则，规则就是写明了哪个域名对应哪个 service，生成一段 nginx 配置.
>
> 3.再写到 nginx-ingress-control 的 pod 里，这个 Ingress controller 的 pod 里运行着一个 Nginx 服务，控制器会把生成的 nginx 配置写入/etc/nginx.conf 文件中.
>
> 4.然后 reload 一下使配置生效。以此达到域名分配置和动态更新的问题。(目前最新版本的 ingress-nginx-controller，用 lua 实现了当 upstream 变化时不用 reload，大大减少了生产环境中由于服务的重启、升级引起的 IP 变化导致的 nginx reload)

`关于lua和nginx会专门在其他专栏讲解`

#### nginx-ingress 工作流程分析

首先，上一张 Controller 整体工作模式架构图

![ingress Controller 架构图](https://tva1.sinaimg.cn/large/006y8mN6gy1g8655g8a6kj30nu0abmz3.jpg)

> 不考虑 nginx 状态收集等附件功能，nginx-ingress 模块在运行时主要包括三个主体：NginxController、Store、SyncQueue. 其中，Store 主要负责从 kubernetes APIServer 收集运行时信息，感知各类资源（如 ingress、service 等）的变化，并及时将更新事件消息（event）写入一个环形管道；SyncQueue 协程定期扫描 syncQueue 队列，发现有任务就执行更新操作，即借助 Store 完成最新运行数据的拉取，然后根据一定的规则产生新的 nginx 配置，（有些更新必须 reload，就本地写入新配置，执行 reload），然后执行动态更新操作，即构造 POST 数据，向本地 Nginx Lua 服务模块发送 post 请求，实现配置更新；NginxController 作为中间的联系者，监听 updateChannel，一旦收到配置更新事件，就向同步队列 syncQueue 里写入一个更新请求。

### 二.Ingress-Nginx 的工作模式

ingress 的部署，需要考虑两个方面：

1. ingress-controller 是作为 pod 来运行的，以什么方式部署比较好
2. ingress 解决了把如何请求路由到集群内部，那它自己怎么暴露给外部比较好

下面列举一些目前常见的部署和暴露方式，具体使用哪种方式还是得根据实际需求来考虑决定。

#### Deployment+LoadBalancer 模式的 Service

> 如果要把 ingress 部署在公有云，那用这种方式比较合适。用 Deployment 部署 ingress-controller，创建一个 type 为 LoadBalancer 的 service 关联这组 pod。大部分公有云，都会为 LoadBalancer 的 service 自动创建一个负载均衡器，通常还绑定了公网地址。只要把域名解析指向该地址，就实现了集群服务的对外暴露。

#### Deployment+NodePort 模式的 Service

> 同样用 deployment 模式部署 ingress-controller，并创建对应的服务，但是 type 为 NodePort。这样，ingress 就会暴露在集群节点 ip 的特定端口上。由于 nodeport 暴露的端口是随机端口，一般会在前面再搭建一套负载均衡器来转发请求。该方式一般用于宿主机是相对固定的环境 ip 地址不变的场景。
> NodePort 方式暴露 ingress 虽然简单方便，但是 NodePort 多了一层 NAT，在请求量级很大时可能对性能会有一定影响。

#### DaemonSet+HostNetwork+nodeSelector

> 用 DaemonSet 结合 nodeselector 来部署 ingress-controller 到特定的 node 上，然后使用 HostNetwork 直接把该 pod 与宿主机 node 的网络打通，直接使用宿主机的 80/433 端口就能访问服务。这时，ingress-controller 所在的 node 机器就很类似传统架构的边缘节点，比如机房入口的 nginx 服务器。该方式整个请求链路最简单，性能相对 NodePort 模式更好。缺点是由于直接利用宿主机节点的网络和端口，一个 node 只能部署一个 ingress-controller pod。比较适合大并发的生产环境使用。

### 三. Ingress-Nginx 的部署

首先看看官方 github 的 yaml 文件

![ingress-nginx-github](https://tva1.sinaimg.cn/large/006y8mN6gy1g8655g1yw3j30tc0cvq56.jpg)

其实 图中的 mandatory.yaml 文件已经整合其他文件的作用包括 rbac 租户 权限 configmap 以及 nginx-ingress-controller 的部署

`本文部署用的第三种方式部署 DaemonSet+HostNetwork+nodeSelector`

由于默认不是用的 hostnetwork 以及 nodeSelector ，需要下载官方 yaml 修改部分

`https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml`

修改前:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-ingress-controller
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: ingress-nginx
      app.kubernetes.io/part-of: ingress-nginx
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ingress-nginx
        app.kubernetes.io/part-of: ingress-nginx
      annotations:
        prometheus.io/port: "10254"
        prometheus.io/scrape: "true"
    spec:
      serviceAccountName: nginx-ingress-serviceaccount
      containers:
        - name: nginx-ingress-controller
          image: quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.25.0
          args:
            - /nginx-ingress-controller
            - --configmap=$(POD_NAMESPACE)/nginx-configuration
            - --tcp-services-configmap=$(POD_NAMESPACE)/tcp-services
            - --udp-services-configmap=$(POD_NAMESPACE)/udp-services
            - --publish-service=$(POD_NAMESPACE)/ingress-nginx
            - --annotations-prefix=nginx.ingress.kubernetes.io
          securityContext:
            allowPrivilegeEscalation: true
            capabilities:
              drop:
                - ALL
              add:
                - NET_BIND_SERVICE
            # www-data -> 33
            runAsUser: 33
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          ports:
            - name: http
              containerPort: 80
            - name: https
              containerPort: 443
          livenessProbe:
            failureThreshold: 3
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 10
          readinessProbe:
            failureThreshold: 3
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 10
```

修改后：

```yaml
# 修改api版本及kind
# apiVersion: apps/v1
# kind: Deployment
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: nginx-ingress-controller
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
spec:
  # 删除Replicas
  # replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: ingress-nginx
      app.kubernetes.io/part-of: ingress-nginx
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ingress-nginx
        app.kubernetes.io/part-of: ingress-nginx
      annotations:
        prometheus.io/port: "10254"
        prometheus.io/scrape: "true"
    spec:
      serviceAccountName: nginx-ingress-serviceaccount
      # 选择对应标签的node
      nodeSelector:
        isIngress: "true"
      # 使用hostNetwork暴露服务
      hostNetwork: true
      containers:
        - name: nginx-ingress-controller
          image: quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.25.0
          args:
            - /nginx-ingress-controller
            - --configmap=$(POD_NAMESPACE)/nginx-configuration
            - --tcp-services-configmap=$(POD_NAMESPACE)/tcp-services
            - --udp-services-configmap=$(POD_NAMESPACE)/udp-services
            - --publish-service=$(POD_NAMESPACE)/ingress-nginx
            - --annotations-prefix=nginx.ingress.kubernetes.io
          securityContext:
            allowPrivilegeEscalation: true
            capabilities:
              drop:
                - ALL
              add:
                - NET_BIND_SERVICE
            # www-data -> 33
            runAsUser: 33
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          ports:
            - name: http
              containerPort: 80
            - name: https
              containerPort: 443
          livenessProbe:
            failureThreshold: 3
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 10
          readinessProbe:
            failureThreshold: 3
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 10
```

并且给某节点打上标签 我这里是给 node1 节点

`kubectl label node node-1 isIngress="true"`

![打标签](https://tva1.sinaimg.cn/large/006y8mN6gy1g8655fwsw1j31bk02jmxp.jpg)

修改完后执行 apply,并检查服务

`kubectl apply -f mandatory.yaml`

![部署后查看](https://tva1.sinaimg.cn/large/006y8mN6gy1g8655fqx9lj30va034mxn.jpg)

可以看到，nginx-controller 的 pod 已经部署在在 node-1 上了

由于配置了 hostnetwork，nginx 已经在 node 主机本地监听 80/443/8181 端口。其中 8181 是 nginx-controller 默认配置的一个 default backend。这样，只要访问 node 主机有公网 IP，就可以直接映射域名来对外网暴露服务了。如果要 nginx 高可用的话，可以在多个 node
上部署，并在前面再搭建一套 LVS+keepalive 做负载均衡。用 hostnetwork 的另一个好处是，如果 lvs 用 DR 模式的话，是不支持端口映射的，这时候如果用 nodeport，暴露非标准的端口，管理起来会很麻烦。

![查看监听端口](https://tva1.sinaimg.cn/large/006y8mN6gy1g8655e31s3j31ez0qywla.jpg)

#### 配置 ingress 资源

部署完 ingress-controller，接下来就按照测试的需求来创建 ingress 资源。

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-test
  annotations:
    kubernetes.io/ingress.class: "nginx"
    # 开启use-regex，启用path的正则匹配
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  rules:
    # 定义域名
    - host: test.ingress.com
      http:
        paths:
          # 不同path转发到不同端口
          - path: /ip
            backend:
              serviceName: s1
              servicePort: 8000
          - path: /host
            backend:
              serviceName: s2
              servicePort: 8000
```

部署资源

`$ kubectl apply -f ingresstest.yaml`

其中 service s1 s2 是我自己定义的两个 flask 容器的 service 端口为 8000

```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: s1
spec:
  replicas: 2
  selector:
    name: s1
  template:
    metadata:
      labels:
        name: s1
    spec:
      containers:
        - name: s1
          image: jxhs/s2:v3
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: s1
spec:
  ports:
    - port: 8000
      targetPort: 8000
  selector:
    name: s1
```

#### 测试访问

部署好以后，做一条本地 host 来模拟解析 test.ingress.com 到 node1 的 ip 地址。测试访问

![访问图1](https://tva1.sinaimg.cn/large/006y8mN6gy1g8655dvbukj30ab03l0sn.jpg)

![访问图2](https://tva1.sinaimg.cn/large/006y8mN6gy1g8655dpg0gj30by03bjrb.jpg)

上面测试的例子是非常简单的，实际 ingress-nginx 的有非常多的配置.后面会介绍一些关于 ingress 源码、ssl 和四层负载均衡方面的东西

#### 最后

- ingress 是 k8s 集群的请求入口，可以理解为对多个 service 的再次抽象
- 通常说的 ingress 一般包括 ingress 资源对象及 ingress-controller 两部分组成
- ingress-controller 有多种实现，社区原生的是 ingress-nginx，根据具体需求选择
- ingress 自身的暴露有多种方式，需要根据基础环境及业务类型选择合适的方式

#### 参考

> https://github.com/kubernetes/ingress-nginx
>
> https://segmentfault.com/a/1190000019908991
>
> https://www.cnblogs.com/k-free-bolg/p/11169111.html
>
> https://blog.csdn.net/shida_csdn/article/details/84032019
>
> https://cloud.tencent.com/developer/article/1475537
