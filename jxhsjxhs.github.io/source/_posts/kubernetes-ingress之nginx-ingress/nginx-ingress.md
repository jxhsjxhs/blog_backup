[TOC]

### 一.Ingress-Nginx是什么以及工作原理介绍

> ​     1.ingress是什么
>
> ​	 2.ingress与ingress-controller组件介绍
>
> ​     3.ingress工作原理	
>
> ​	 4.nginx工作流程分析

#### ingress介绍



在k8s 中  service就有可以让pod的工作端口暴露出来的三种方式

> ClusterIP、NodePort与LoadBalance，这几种方式都是在service的维度提供的，service的作用体现在两个方面，对集群内部，它不断跟踪pod的变化，更新endpoint中对应pod的对象，提供了ip不断变化的pod的服务发现机制，对集群外部，他类似负载均衡器，可以在集群内外部对pod进行访问。但是，单独用service暴露服务的方式，在实际生产环境中不太合适：

> 1 . ClusterIP的方式只能在集群内部访问。
> 2 . NodePort方式的话，测试环境使用还行，当有几十上百的服务在集群中运行时，NodePort的端口管理是灾难。
> 3 . LoadBalance方式受限于云平台，且通常在云平台部署ELB还需要额外的费用。

所幸k8s还提供了一种集群维度暴露服务的方式，也就是ingress。ingress可以简单理解为service的service，他通过独立的ingress对象来制定请求转发的规则，把请求路由到一个或多个service中。这样就把服务与请求规则解耦了，可以从业务维度统一考虑业务的暴露，而不用为每个service单独考虑。

图1

截至目前，nginx-ingress 已经能够完成 7/4 层的代理功能 (本文基于目前最新版本ingress-nginx0.25.0)



#### ingress与ingress-controller组件介绍



要理解ingress，需要区分两个概念，ingress和ingress-controller：

- ingress对象：
  指的是k8s中的一个api对象，一般用yaml配置。作用是定义请求如何转发到service的规则，可以理解为配置模板。
- ingress-controller：
  具体实现反向代理及负载均衡的程序，对ingress定义的规则进行解析，根据配置的规则来实现请求转发。

简单来说，ingress-controller才是负责具体转发的组件，通过各种方式将它暴露在集群入口，外部对集群的请求流量会先到ingress-controller，而ingress对象是用来告诉ingress-controller该如何转发请求，比如哪些域名哪些path要转发到哪些服务等等。

------------------------------------

ingress-controller

ingress-controller并不是k8s自带的组件，实际上ingress-controller只是一个统称，用户可以选择不同的ingress-controller实现，目前，由k8s维护的ingress-controller只有google云的GCE与ingress-nginx两个，其他还有很多第三方维护的ingress-controller，具体可以参考[官方文档](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/#additional-controllers)。但是不管哪一种ingress-controller，实现的机制都大同小异，只是在具体配置上有差异。一般来说，ingress-controller的形式都是一个pod，里面跑着daemon程序和反向代理程序。daemon负责不断监控集群的变化，根据ingress对象生成配置并应用新配置到反向代理，比如nginx-ingress就是动态生成nginx配置，动态更新upstream，并在需要的时候reload程序应用新配置。为了方便，后面的例子都以k8s官方维护的nginx-ingress为例。

------------------------

ingress

ingress是一个API对象，和其他对象一样，通过yaml文件来配置。ingress通过http或https暴露集群内部service，给service提供外部URL、负载均衡、SSL/TLS能力以及基于host的方向代理。ingress要依靠ingress-controller来具体实现以上功能。



#### ingress工作原理



图2

Nginx 对后端运行的服务（Service1、Service2）提供反向代理，在配置文件中配置了域名与后端服务 Endpoints 的对应关系。客户端通过使用 DNS 服务或者直接配置本地的 hosts 文件，将域名都映射到 Nginx 代理服务器。当客户端访问 service1.com 时，浏览器会把包含域名的请求发送给 nginx 服务器，nginx 服务器根据传来的域名，选择对应的 Service，这里就是选择 Service 1 后端服务，然后根据一定的负载均衡策略，选择 Service1 中的某个容器接收来自客户端的请求并作出响应。过程很简单，nginx 在整个过程中仿佛是一台根据域名进行请求转发的“路由器”，这也就是7层代理的整体工作流程了！

> 1.ingress controller通过和kubernetes api交互，动态的去感知集群中ingress规则变化.
>
> 2.然后读取它，按照自定义的规则，规则就是写明了哪个域名对应哪个service，生成一段nginx配置.
>
> 3.再写到nginx-ingress-control的pod里，这个Ingress controller的pod里运行着一个Nginx服务，控制器会把生成的nginx配置写入/etc/nginx.conf文件中.
>
> 4.然后reload一下使配置生效。以此达到域名分配置和动态更新的问题。(目前最新版本的ingress-nginx-controller，用lua实现了当upstream变化时不用reload，大大减少了生产环境中由于服务的重启、升级引起的IP变化导致的nginx reload)

`关于lua和nginx会专门在其他专栏讲解`



#### nginx-ingress 工作流程分析



首先，上一张整体工作模式架构图

图三

>不考虑 nginx 状态收集等附件功能，nginx-ingress 模块在运行时主要包括三个主体：NginxController、Store、SyncQueue.   其中，Store 主要负责从 kubernetes APIServer 收集运行时信息，感知各类资源（如 ingress、service等）的变化，并及时将更新事件消息（event）写入一个环形管道；SyncQueue 协程定期扫描 syncQueue 队列，发现有任务就执行更新操作，即借助 Store 完成最新运行数据的拉取，然后根据一定的规则产生新的 nginx 配置，（有些更新必须 reload，就本地写入新配置，执行 reload），然后执行动态更新操作，即构造 POST 数据，向本地 Nginx Lua 服务模块发送 post 请求，实现配置更新；NginxController 作为中间的联系者，监听 updateChannel，一旦收到配置更新事件，就向同步队列 syncQueue 里写入一个更新请求。



### 二.Ingress-Nginx的工作模式

ingress的部署，需要考虑两个方面：

1. ingress-controller是作为pod来运行的，以什么方式部署比较好
2. ingress解决了把如何请求路由到集群内部，那它自己怎么暴露给外部比较好



下面列举一些目前常见的部署和暴露方式，具体使用哪种方式还是得根据实际需求来考虑决定。



#### Deployment+LoadBalancer模式的Service

> 如果要把ingress部署在公有云，那用这种方式比较合适。用Deployment部署ingress-controller，创建一个type为LoadBalancer的service关联这组pod。大部分公有云，都会为LoadBalancer的service自动创建一个负载均衡器，通常还绑定了公网地址。只要把域名解析指向该地址，就实现了集群服务的对外暴露。

#### Deployment+NodePort模式的Service

> 同样用deployment模式部署ingress-controller，并创建对应的服务，但是type为NodePort。这样，ingress就会暴露在集群节点ip的特定端口上。由于nodeport暴露的端口是随机端口，一般会在前面再搭建一套负载均衡器来转发请求。该方式一般用于宿主机是相对固定的环境ip地址不变的场景。
> NodePort方式暴露ingress虽然简单方便，但是NodePort多了一层NAT，在请求量级很大时可能对性能会有一定影响。

#### DaemonSet+HostNetwork+nodeSelector

> 用DaemonSet结合nodeselector来部署ingress-controller到特定的node上，然后使用HostNetwork直接把该pod与宿主机node的网络打通，直接使用宿主机的80/433端口就能访问服务。这时，ingress-controller所在的node机器就很类似传统架构的边缘节点，比如机房入口的nginx服务器。该方式整个请求链路最简单，性能相对NodePort模式更好。缺点是由于直接利用宿主机节点的网络和端口，一个node只能部署一个ingress-controller pod。比较适合大并发的生产环境使用。



### 三. Ingress-Nginx的部署

首先看看官方github的yuaml文件

图4(ingress-nginx github)

其实 图中的 mandatory.yaml 文件已经整合其他文件的作用包括 rbac  租户 权限  configmap 以及  nginx-ingress-controller 的部署

`本文部署用的第三种方式部署  DaemonSet+HostNetwork+nodeSelector`

由于默认不是用的hostnetwork 以及 nodeSelector ，需要下载官方yaml修改部分

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

并且给某节点打上标签  我这里是给node1节点

`kubectl label node node-1 isIngress="true"`

图5

修改完后执行apply,并检查服务

` kubectl apply -f mandatory.yaml`

图6

可以看到，nginx-controller的pod已经部署在在node-1上了

由于配置了hostnetwork，nginx已经在node主机本地监听80/443/8181端口。其中8181是nginx-controller默认配置的一个default backend。这样，只要访问node主机有公网IP，就可以直接映射域名来对外网暴露服务了。如果要nginx高可用的话，可以在多个node
上部署，并在前面再搭建一套LVS+keepalive做负载均衡。用hostnetwork的另一个好处是，如果lvs用DR模式的话，是不支持端口映射的，这时候如果用nodeport，暴露非标准的端口，管理起来会很麻烦。

图7

#### 配置ingress资源

部署完ingress-controller，接下来就按照测试的需求来创建ingress资源。

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

其中 service s1 s2 是我自己定义的两个flask容器的service 端口为8000 

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

部署好以后，做一条本地host来模拟解析test.ingress.com到node1的ip地址。测试访问

图8

图9

上面测试的例子是非常简单的，实际ingress-nginx的有非常多的配置.后面会介绍一些关于ingress源码、ssl  和四层负载均衡方面的东西

#### 最后

- ingress是k8s集群的请求入口，可以理解为对多个service的再次抽象
- 通常说的ingress一般包括ingress资源对象及ingress-controller两部分组成
- ingress-controller有多种实现，社区原生的是ingress-nginx，根据具体需求选择
- ingress自身的暴露有多种方式，需要根据基础环境及业务类型选择合适的方式



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