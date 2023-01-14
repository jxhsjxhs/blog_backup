---
title: 使用 skopeo 操作容器镜像
date: 2020-07-15 13:28:00
tags:
---


### 背景
今天项目组突然提出一个需求,跟其他应用放对接的时候提供一个镜像仓库。对接放把应用上传完以后。我们需要将这些镜像都打成tar包存到oss中。
```
问题如下:
  镜像仓库每个都很大(内部是数据模型以及算法)怎么能保证完整下下来不影响业务网络
  镜像都得打tar包，但是本地存储限制 没那么大  并且耗时
  后续扩展跟其他库同步麻烦。需要一个个load进去然后倒入

```
根据以上的需求进行分析,目的很明确 

> 1.需要找到一个能直接下载docker镜像并且最好是直接打tar包的工具
> 2.最好能镜像库与库之间的同步
> 3.这个工具最好不依赖docker

为啥说最好不依赖docker呢，这里并不是对docker有啥歧视的地方,见下图
![](/img/newimg/007S8ZIlgy1ggrlwuw4j9j317g04g0va.jpg)
我明明只需要个命令行工具来进行镜像的下载上传，并不需要真正的run起来。但是docker傻乎乎的需要程序进行守护启动才能进行镜像下载  增大维护度

### skopeo的使用
到github找了找,发现官方已经有这样的工具了 并且完美支持我的需求 [项目地址](https://github.com/containers/skopeo)

#### 安装
```
# centos
yum install skopeo
```
其他系统安装见[安装文档](https://github.com/containers/skopeo/blob/master/install.md)

##### 不借助 docker 下载镜像
```
skopeo --insecure-policy copy docker://nginx:1.17.6 docker-archive:/tmp/nginx.tar
```
`--insecure-policy` 选项用于忽略安全策略配置文件，该命令将会直接通过 http 下载目标镜像并存储为 `/tmp/nginx.tar`，此文件可以直接通过 `docker load` 命令导入

##### 从 docker daemon 导出镜像
```
skopeo --insecure-policy copy docker-daemon:nginx:1.17.6 docker-archive:/tmp/nginx.tar
```
该命令将会从 docker daemon 导出镜像到 `/tmp/nginx.tar`；为什么不用 docker save？因为我是偷懒 dest 也是 docker-archive，实际上 skopeo 可以导出为其他格式比如 `oci`、`oci-archive`、`ostree` 等

##### 远程获取镜像的信息
skopeo 可以在不用下载镜像的情况下，获取镜像信息
```

# skopeo inspect docker://docker.io/centos
{
    "Name": "docker.io/library/centos",
    "Digest": "sha256:fe8d824220415eed5477b63addf40fb06c3b049404242b31982106ac204f6700",
    "RepoTags": [
        "5.11",
        "5",
        "6.10",
        "6.6",
        "6.7",
        "6.8",
        "6.9",
        "6",
        "7.0.1406",
        "7.1.1503",
        "7.2.1511",
        "7.3.1611",
        "7.4.1708",
        "7.5.1804",
        "7.6.1810",
        "7.7.1908",
        "7",
        "8.1.1911",
        "8",
        "centos5.11",
        "centos5",
        "centos6.10",
        "centos6.6",
        "centos6.7",
        "centos6.8",
        "centos6.9",
        "centos6",
        "centos7.0.1406",
        "centos7.1.1503",
        "centos7.2.1511",
        "centos7.3.1611",
        "centos7.4.1708",
        "centos7.5.1804",
        "centos7.6.1810",
        "centos7.7.1908",
        "centos7",
        "centos8.1.1911",
        "centos8",
        "latest"
    ],
    "Created": "2020-01-18T00:26:46.850750902Z",
    "DockerVersion": "18.06.1-ce",
    "Labels": {
        "org.label-schema.build-date": "20200114",
        "org.label-schema.license": "GPLv2",
        "org.label-schema.name": "CentOS Base Image",
        "org.label-schema.schema-version": "1.0",
        "org.label-schema.vendor": "CentOS",
        "org.opencontainers.image.created": "2020-01-14 00:00:00-08:00",
        "org.opencontainers.image.licenses": "GPL-2.0-only",
        "org.opencontainers.image.title": "CentOS Base Image",
        "org.opencontainers.image.vendor": "CentOS"
    },
    "Architecture": "amd64",
    "Os": "linux",
    "Layers": [
        "sha256:8a29a15cefaeccf6545f7ecf11298f9672d2f0cdaf9e357a95133ac3ad3e1f07"
    ]
}
```
docker://: 是使用 Docker Registry HTTP API V2 进行连接远端
docker.io: 远程仓库
centos: 镜像名称

##### 镜像仓的认证文件
认证文件默认存放在 $HOME/.docker/config.json
文件内容
```
{
	"auths": {
		"myregistrydomain.com:5000": {
			"auth": "dGVzdHVzZXI6dGVzdHBhc3N3b3Jk",
			"email": "stuf@ex.cm"
		}
	}
}
```


##### 其他命令
skopeo 还有一些其他的实用命令，比如 sync 可以在两个位置之间同步镜像.

### 源码赏析

暂时先埋个坑 以后再写