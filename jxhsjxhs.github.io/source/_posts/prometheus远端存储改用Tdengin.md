---
title: prometheus远端存储改用Tdengin
date: 2022-12-26 09:45:42
tags:
index_img: https://tva1.sinaimg.cn/large/008vxvgGgy1h9h0g9mta2j30uw0cc757.jpg
banner_img: https://tva1.sinaimg.cn/large/008vxvgGgy1h9h0g9mta2j30uw0cc757.jpg
---
### Prometheus
prometheus 在监控方面的能力是有目共睹的，我们在实施监控方案时，为满足大规模应用集群的监控及数据的高效查询能力，通常也会考虑将prometheus的部署扩展为集群。对于prometheus集群的搭建，常见的是官方推荐的联邦模式，但该模式是一种分层结构，在查询监控数据时，仍对下层的Prometheus有一定性能影响。根据官方文档的阅读及个人对集群的理解，我设计了一个基于Tdengine 的prometheus读写分离方案。 该方案结合了Prometheus的远程读写功能及tdengine 的高性能查询及数据压缩能力，有效控制了prometheus集群部署的规模和数据存储压缩的问题，相对规模化数据也提升了查询性能。对于prometheus 的远端存储方案，网上很多文章都是基于influxdb的,当前方案选用的Tdengine是一款开源、云原生的时序数据库，相对influxdb，其提供了优秀的查询和集群能力，更多优点可见：[TDengine和InfluxDB的性能对比报告](https://www.taosdata.com/engineering/5969.html)

得益于Prometheus 提供了 remote_write 和 remote_read 接口来利用其它数据库产品作为它的存储引擎。为了让 Prometheus 生态圈的用户能够利用 TDengine 的高效写入和查询，TDengine 也提供了对这两个接口的支持。

通过适当的配置， Prometheus 的数据可以通过 remote_write 接口存储到 TDengine 中，也可以通过 remote_read 接口来查询存储在 TDengine 中的数据，充分利用 TDengine 对时序数据的高效存储查询性能和集群处理能力。
![](https://tva1.sinaimg.cn/large/008vxvgGgy1h9gzchcypgj319e0tc76x.jpg)
通过图中读写分离的方案，可以高效的实现监控数据以及监控组件的分离、横向扩容等。

### taosAdapter
其中Tdengine 支持 prometheus 是通过其内建组件taosAdapter 实现的，taosAdapter是 TDengine 集群和应用程序之间的桥梁和适配器。其不仅支持Prometheus数据的远程读写，还支持如下功能：
```
RESTful 接口
兼容 InfluxDB v1 写接口
兼容 OpenTSDB JSON 和 telnet 格式写入
无缝连接到 Telegraf
无缝连接到 collectd
无缝连接到 StatsD
```
![](https://tva1.sinaimg.cn/large/008vxvgGgy1h9gzf94gdqj31i60jg416.jpg)


### 部署方案

#### 部署Tdengine集群

本次测试使用`docker-compose`部署单机多实例的Tdengine节点模拟生产环境正常集群情况
taosAdapter 在 TDengine 容器中默认是启动的。如果想要禁用它，在启动时指定环境变量 TAOS_DISABLE_ADAPTER=true
同时为了部署灵活起见，可以在独立的容器中启动 taosAdapter
如果要部署多个 taosAdapter 来提高吞吐量并提供高可用性，推荐配置方式为使用 nginx 等反向代理来提供统一的访问入口。具体配置方法请参考 nginx 的官方文档。如下是示例：
```
version: "3"

networks:
  inter:

services:
  td-1:
    image: tdengine/tdengine:$VERSION
    networks:
      - inter
    environment:
      TAOS_FQDN: "td-1"
      TAOS_FIRST_EP: "td-1"
    volumes:
      - taosdata-td1:/var/lib/taos/
      - taoslog-td1:/var/log/taos/
  td-2:
    image: tdengine/tdengine:$VERSION
    networks:
      - inter
    environment:
      TAOS_FQDN: "td-2"
      TAOS_FIRST_EP: "td-1"
    volumes:
      - taosdata-td2:/var/lib/taos/
      - taoslog-td2:/var/log/taos/
  adapter:
    image: tdengine/tdengine:$VERSION
    entrypoint: "taosadapter"
    networks:
      - inter
    environment:
      TAOS_FIRST_EP: "td-1"
      TAOS_SECOND_EP: "td-2"
    deploy:
      replicas: 4
  nginx:
    image: nginx
    depends_on:
      - adapter
    networks:
      - inter
    ports:
      - 6041:6041
      - 6044:6044/udp
    command: [
        "sh",
        "-c",
        "while true;
        do curl -s http://adapter:6041/-/ping >/dev/null && break;
        done;
        printf 'server{listen 6041;location /{proxy_pass http://adapter:6041;}}'
        > /etc/nginx/conf.d/rest.conf;
        printf 'stream{server{listen 6044 udp;proxy_pass adapter:6044;}}'
        >> /etc/nginx/nginx.conf;cat /etc/nginx/nginx.conf;
        nginx -g 'daemon off;'",
      ]
volumes:
  taosdata-td1:
  taoslog-td1:
  taosdata-td2:
  taoslog-td2:
```
查看部署状态
```
tdengin默认账号密码 root:taosdata
# 进入容器环境
docker exec -it tdengine /bin/bash
# 进入taos 数据库控制台
taos
# 创建prometheus数据库
# keep 数据保留180 天,默认为3650天，days 每10天为一个数据文件，
# comp 数据文件的压缩程度为1，0：关闭，1:一阶段压缩，2:两阶段压缩。默认为2
create database prometheus keep 180 days 10 comp 1;
# 退出
quit

# 用默认密码测试，在返回结果中可以看到 prometheus 数据库
curl -u root:taosdata -d 'show databases' 127.0.0.1:6041/rest/sql

# 也可以修改数据库参数
alter database prometheus keep 90;

```
![](https://tva1.sinaimg.cn/large/008vxvgGgy1h9h00nhoxlj31980u0dif.jpg)

#### Prometheus部署
对于开启prometheus的remote_write 是非常简单的，只需在配置文件中添加如下配置即可:

新建目录 prometheus，编辑配置文件prometheus.yml
```
mkdir /etc/prometheus
cd /etc/prometheus/
vim prometheus.yml
```
```
# 远程写，对只读prometheus 配置时，屏蔽掉远程写配置即可
remote_write:
- url: "http://x.x.x.x:6041/prometheus/v1/remote_write/prometheus"
  basic_auth:
    username: root
    password: taosdata

# 远程读
remote_read:
  - url: "http://x.x.x.x:6041/prometheus/v1/remote_read/prometheus"
    basic_auth:
      username: root
      password: taosdata
```
查看Prometheus配置
![](https://tva1.sinaimg.cn/large/008vxvgGgy1h9h03ikt0rj30w20u0acs.jpg)

启动prometheus
```
docker run  -d \
  -p 9090:9090 \
  -v /etc/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml  \
  prom/prometheus
```
进入tdengin容器节点，查看数据是否进入
![](https://tva1.sinaimg.cn/large/008vxvgGgy1h9h0b6wke2j30u00wbtdj.jpg)