---
title: apisix介绍以及食用方法
date: 2020-11-30 10:27:25
tags:
---








## Apache APISIX 是什么？

Apache APISIX 是一个动态、实时、高性能的 API 网关，基于 Nginx 网络库和 etcd 实现，
提供负载均衡、动态上游、灰度发布、服务熔断、身份认证、可观测性等丰富的流量管理功能。

你可以使用 Apache APISIX 来处理传统的南北向流量，以及服务间的东西向流量，
也可以当做 k8s ingress controller 来使用。

Apache APISIX 的技术架构如下图所示：

![](/img/newimg/0081Kckwgy1gl85xhdvnoj30th0fmju8.jpg)

## 目录

- [特性](#特性)
- [立刻开始](#立刻开始)
- [控制台](#控制台)
- [性能测试](#性能测试)
- [Apache APISIX 和 Kong 的比较](#apache-apisix-和-kong-的比较)
- [开放治理](#开放治理)
- [社区](#社区)
- [视频和文章](#视频和文章)


## 特性

你可以把 Apache APISIX 当做流量入口，来处理所有的业务数据，包括动态路由、动态上游、动态证书、
A/B 测试、金丝雀发布(灰度发布)、蓝绿部署、限流限速、抵御恶意攻击、监控报警、服务可观测性、服务治理等。

- **全平台**

  - 云原生: 平台无关，没有供应商锁定，无论裸机还是 Kubernetes，APISIX 都可以运行。
  - 运行环境: OpenResty 和 Tengine 都支持。
  - 支持 ARM64: 不用担心底层技术的锁定。

- **多协议**

  - [TCP/UDP 代理](doc/zh-cn/stream-proxy.md): 动态 TCP/UDP 代理。
  - [动态 MQTT 代理](doc/zh-cn/plugins/mqtt-proxy.md): 支持用 `client_id` 对 MQTT 进行负载均衡，同时支持 MQTT [3.1.\*](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html) 和 [5.0](https://docs.oasis-open.org/mqtt/mqtt/v5.0/mqtt-v5.0.html) 两个协议标准。
  - [gRPC 代理](doc/zh-cn/grpc-proxy.md)：通过 APISIX 代理 gRPC 连接，并使用 APISIX 的大部分特性管理你的 gRPC 服务。
  - [gRPC 协议转换](doc/zh-cn/plugins/grpc-transcode.md)：支持协议的转换，这样客户端可以通过 HTTP/JSON 来访问你的 gRPC API。
  - Websocket 代理
  - Proxy Protocol
  - Dubbo 代理：基于 Tengine，可以实现 Dubbo 请求的代理。
  - HTTP(S) 反向代理
  - [SSL](doc/zh-cn/https.md)：动态加载 SSL 证书。

- **全动态能力**

  - [热更新和热插件](doc/zh-cn/plugins.md): 无需重启服务，就可以持续更新配置和插件。
  - [代理请求重写](doc/zh-cn/plugins/proxy-rewrite.md): 支持重写请求上游的`host`、`uri`、`schema`、`enable_websocket`、`headers`信息。
  - [输出内容重写](doc/zh-cn/plugins/response-rewrite.md): 支持自定义修改返回内容的 `status code`、`body`、`headers`。
  - [Serverless](doc/zh-cn/plugins/serverless.md): 在 APISIX 的每一个阶段，你都可以添加并调用自己编写的函数。
  - 动态负载均衡：动态支持有权重的 round-robin 负载平衡。
  - 支持一致性 hash 的负载均衡：动态支持一致性 hash 的负载均衡。
  - [健康检查](doc/zh-cn/health-check.md)：启用上游节点的健康检查，将在负载均衡期间自动过滤不健康的节点，以确保系统稳定性。
  - 熔断器: 智能跟踪不健康上游服务。
  - [代理镜像](doc/zh-cn/plugins/proxy-mirror.md): 提供镜像客户端请求的能力。

- **精细化路由**

  - [支持全路径匹配和前缀匹配](doc/router-radixtree.md#how-to-use-libradixtree-in-apisix)
  - [支持使用 Nginx 所有内置变量做为路由的条件](/doc/router-radixtree.md#how-to-filter-route-by-nginx-builtin-variable)，所以你可以使用 `cookie`, `args` 等做为路由的条件，来实现灰度发布、A/B 测试等功能
  - 支持[各类操作符做为路由的判断条件](https://github.com/iresty/lua-resty-radixtree#operator-list)，比如 `{"arg_age", ">", 24}`
  - 支持[自定义路由匹配函数](https://github.com/iresty/lua-resty-radixtree/blob/master/t/filter-fun.t#L10)
  - IPv6：支持使用 IPv6 格式匹配路由
  - 支持路由的[自动过期(TTL)](doc/zh-cn/admin-api.md#route)
  - [支持路由的优先级](doc/router-radixtree.md#3-match-priority)
  - [支持批量 Http 请求](doc/zh-cn/plugins/batch-requests.md)

- **安全防护**

  - 多种身份认证方式: [key-auth](doc/zh-cn/plugins/key-auth.md), [JWT](doc/zh-cn/plugins/jwt-auth.md), [basic-auth](doc/zh-cn/plugins/basic-auth.md), [wolf-rbac](doc/zh-cn/plugins/wolf-rbac.md)。
  - [IP 黑白名单](doc/zh-cn/plugins/ip-restriction.md)
  - [Referer 白名单](doc/zh-cn/plugins/referer-restriction.md)
  - [IdP 支持](doc/plugins/openid-connect.md): 支持外部的身份认证服务，比如 Auth0，Okta，Authing 等，用户可以借此来对接 Oauth2.0 等认证方式。
  - [限制速率](doc/zh-cn/plugins/limit-req.md)
  - [限制请求数](doc/zh-cn/plugins/limit-count.md)
  - [限制并发](doc/zh-cn/plugins/limit-conn.md)
  - 防御 ReDoS(正则表达式拒绝服务)：内置策略，无需配置即可抵御 ReDoS。
  - [CORS](doc/zh-cn/plugins/cors.md)：为你的 API 启用 CORS。
  - [URI 拦截器](doc/zh-cn/plugins/uri-blocker.md)：根据 URI 拦截用户请求。
  - [请求验证器](doc/zh-cn/plugins/request-validation.md)。

- **运维友好**

  - OpenTracing 可观测性: 支持 [Apache Skywalking](doc/zh-cn/plugins/skywalking.md) 和 [Zipkin](doc/zh-cn/plugins/zipkin.md)。
  - 对接外部服务发现：除了内置的 etcd 外，还支持 `Consul` 和 `Nacos` 的 [DNS 发现模式](https://github.com/apache/apisix/issues/1731#issuecomment-646392129)，以及 [Eureka](doc/zh-cn/discovery.md)。
  - 监控和指标: [Prometheus](doc/zh-cn/plugins/prometheus.md)
  - 集群：APISIX 节点是无状态的，创建配置中心集群请参考 [etcd Clustering Guide](https://github.com/etcd-io/etcd/blob/master/Documentation/op-guide/clustering.md)。
  - 高可用：支持配置同一个集群内的多个 etcd 地址。
  - 控制台: 内置控制台来操作 APISIX 集群。
  - 版本控制：支持操作的多次回滚。
  - CLI: 使用命令行来启动、关闭和重启 APISIX。
  - [单机模式](doc/zh-cn/stand-alone.md): 支持从本地配置文件中加载路由规则，在 kubernetes(k8s) 等环境下更友好。
  - [全局规则](doc/zh-cn/architecture-design.md#Global-Rule)：允许对所有请求执行插件，比如黑白名单、限流限速等。
  - 高性能：在单核上 QPS 可以达到 18k，同时延迟只有 0.2 毫秒。
  - [故障注入](doc/zh-cn/plugins/fault-injection.md)
  - [REST Admin API](doc/zh-cn/admin-api.md): 使用 REST Admin API 来控制 Apache APISIX，默认只允许 127.0.0.1 访问，你可以修改 `conf/config.yaml` 中的 `allow_admin` 字段，指定允许调用 Admin API 的 IP 列表。同时需要注意的是，Admin API 使用 key auth 来校验调用者身份，**在部署前需要修改 `conf/config.yaml` 中的 `admin_key` 字段，来保证安全。**
  - 外部日志记录器：将访问日志导出到外部日志管理工具。([HTTP Logger](doc/plugins/http-logger.md), [TCP Logger](doc/plugins/tcp-logger.md), [Kafka Logger](doc/plugins/kafka-logger.md), [UDP Logger](doc/plugins/udp-logger.md))

- **高度可扩展**
  - [自定义插件](doc/zh-cn/plugin-develop.md): 允许挂载常见阶段，例如`init`, `rewrite`，`access`，`balancer`,`header filer`，`body filter` 和 `log` 阶段。
  - 自定义负载均衡算法：可以在 `balancer` 阶段使用自定义负载均衡算法。
  - 自定义路由: 支持用户自己实现路由算法。





## Apache APISIX 和 Kong 的比较

#### API 网关核心功能点，两者均已覆盖

| **功能**             | **Apache APISIX** | **KONG** |
| :------------------- | :---------------- | :------- |
| **动态上游**         | 支持              | 支持     |
| **动态路由**         | 支持              | 支持     |
| **健康检查和熔断器** | 支持              | 支持     |
| **动态 SSL 证书**    | 支持              | 支持     |
| **七层和四层代理**   | 支持              | 支持     |
| **分布式追踪**       | 支持              | 支持     |
| **自定义插件**       | 支持              | 支持     |
| **REST API**         | 支持              | 支持     |
| **CLI**              | 支持              | 支持     |

#### Apache APISIX 的优势

| **功能**                              | **Apache APISIX**                       | **KONG**               |
| :------------------------------------ | :-------------------------------------- | :--------------------- |
| 项目归属                              | Apache 软件基金会                       | Kong Inc.              |
| 技术架构                              | Nginx + etcd                            | Nginx + postgres       |
| 交流渠道                              | 微信群、QQ 群、邮件列表、Github、meetup | Github、论坛、freenode |
| 单核 QPS (开启限流和 prometheus 插件) | 18000                                   | 1700                   |
| 平均延迟                              | 0.2 毫秒                                | 2 毫秒                 |
| 支持 Dubbo 代理                       | 是                                      | 否                     |
| 配置回滚                              | 是                                      | 否                     |
| 支持生命周期的路由                    | 是                                      | 否                     |
| 插件热更新                            | 是                                      | 否                     |
| 用户自定义：负载均衡算法、路由        | 是                                      | 否                     |
| resty <--> gRPC 转码                  | 是                                      | 否                     |
| 支持 Tengine 作为运行时               | 是                                      | 否                     |
| MQTT 协议支持                         | 是                                      | 否                     |
| 配置生效时间                          | 事件通知，低于 1 毫秒更新               | 定期轮询，5 秒         |
| 自带控制台                            | 是                                      | 否                     |
| 对接外部身份认证服务                  | 是                                      | 否                     |
| 配置中心高可用(HA)                    | 是                                      | 否                     |
| 指定时间窗口的限速                    | 是                                      | 否                     |
| 支持任何 Nginx 变量做路由条件         | 是                                      | 否                     |

性能对比测试[详细内容如下](https://gist.github.com/membphis/137db97a4bf64d3653aa42f3e016bd01)。


## 视频和文章
- 2020.10.16 [Apache APISIX: How to implement plugin orchestration in API Gateway](https://www.youtube.com/watch?v=iEegNXOtEhQ)
- 2020.10.16 [Improve Apache APISIX observability with Apache Skywalking](https://www.youtube.com/watch?v=DleVJwPs4i4)
- 2020.1.17 [API 网关 Apache APISIX 和 Kong 的选型对比](https://mp.weixin.qq.com/s/c51apneVj0O9yxiZAHF34Q)
- 2019.12.14 [从 0 到 1：Apache APISIX 的 Apache 之路](https://zhuanlan.zhihu.com/p/99620158)
- 2019.12.14 [基于 Apache APISIX 的下一代微服务架构](https://www.upyun.com/opentalk/445.html)
- 2019.10.30 [Apache APISIX 微服务架构极致性能架构解析](https://www.upyun.com/opentalk/440.html)
- 2019.9.27 [想把 APISIX 运行在 ARM64 平台上？只要三步](https://zhuanlan.zhihu.com/p/84467919)
- 2019.8.31 [APISIX 技术选型、测试和持续集成](https://www.upyun.com/opentalk/433.html)
- 2019.8.31 [APISIX 高性能实战 2](https://www.upyun.com/opentalk/437.html)
- 2019.7.6 [APISIX 高性能实战](https://www.upyun.com/opentalk/429.html)




## 总结
总的来说 apisix作为云原生网关,比其他的性能好的同时，稳定性可扩展性 都有质的提升。作为新一代网关的考虑范围内。