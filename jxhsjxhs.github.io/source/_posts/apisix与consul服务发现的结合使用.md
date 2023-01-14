---
title: apisix与consul服务发现的结合使用
date: 2020-11-30 17:05:18
tags:
---

首先简单介绍一下apisix,是一个机遇openresty开发的云原生网关。功能类比于nginx+upsync 可无reload，apisix支持自身配置放在etcd中，原生高可用架构。并且支持 `consul`  `eruka`  `nacos`。

## 实践逻辑如下


#### 安装以下实验环境
以下三个点作为验证环境的安装步骤。
```
1.安装好apisix以及相关依赖(openresty,etcd)
2.安装好consul组件作为服务注册与发现。
3.run demo案例作为业务服务。
```

#### 验证逻辑
```
1.run demo代码,本身是一个http服务,并且把自己注册到consul中,持续健康检查监听。
2.访问 demo的http服务发现可访问
3.在apisix中创建url,后端服务对应demo注册到consul的servername。
4.使用apisix创建的url访问服务，发现访问结果与之前一致。
```


## Install Consul
1. download consul
```
wget https://releases.hashicorp.com/consul/1.7.3/consul_1.7.3_linux_amd64.zip
```

2. unzip to `/usr/bin` 

```
sudo unzip consul_1.7.3_linux_amd64.zip -d /usr/bin
```

3. create consul service file
```
sudo vim /lib/systemd/system/consul.service

[Unit]
Description=consul
[Service]
ExecStart=/usr/bin/consul agent -config-dir /etc/consul
KillSignal=SIGINT
```

4. create server json file
```
sudo mkdir /etc/consul/

sudo vim /etc/consul/server.json

{
	"data_dir": "/var/consul",
	"log_level": "INFO",
	"node_name": "test",
	"server": true,
	"ui": true,
	"bootstrap_expect": 1,
	"client_addr": "0.0.0.0",
	"advertise_addr": "127.0.0.1",
	"ports": {
		"dns": 53
	},	
	"advertise_addr_wan": "127.0.0.1"
}
```

5. start consul
```
sudo systemctl start consul
```

## start service - golang version
![](/img/newimg/0081Kckwgy1glwqp0m8muj30qj0qbjvm.jpg)

```
git clone https://github.com/api7/consul-test-golang.git

yum -y install glang 

go env -w GO111MODULE=on

go env -w GOPROXY=https://goproxy.io,direct


cd consul-test-golang

nohup go run main.go &
```


## install etcd  -- need by Apache APISIX
```
sudo yum install etcd

nohup /usr/bin/etcd --enable-v2=true &
```

## install openresty -- need by Apache APISIX

```
wget https://openresty.org/package/centos/openresty.repo

sudo mv openresty.repo /etc/yum.repos.d/

sudo yum install openresty -y
```

## install Apache APISIX

1. install from RPM, and you can get the latest version from https://github.com/apache/incubator-apisix/releases

```
wget https://github.com/apache/incubator-apisix/releases/download/1.3/apisix-1.3-0.el7.noarch.rpm

sudo yum install apisix-1.3-0.el7.noarch.rpm -y
```

2. change config.yaml

vi /usr/local/apisix/conf/config.yaml

add consul address to `dns_resolver`：

```
  dns_resolver:
   - 127.0.0.1
```

3. start Apache APISIX:
```
sudo apisix start
```

## Test

1. add route in Apache APISIX:
```
curl http://127.0.0.1:9080/apisix/admin/routes/1 -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' -X PUT -i -d '
{
    "uri": "/healthz",
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "go-consul-test.service.consul:8080": 1
        }
    }
}'

```

**go-consul-test.service.consul is registered DNS SRV by consul-test-golang service**


2. test：
![](/img/newimg/0081Kckwgy1glwqqxoe77j313y086q47.jpg)

```
curl http://127.0.0.1:8080/healthz | jq
```

![](/img/newimg/0081Kckwgy1glwqsd3qemj314g07u75i.jpg)
```
curl http://127.0.0.1:9080/healthz | jq 

```
能看该运行的demo已经被apisix给封装起来了。