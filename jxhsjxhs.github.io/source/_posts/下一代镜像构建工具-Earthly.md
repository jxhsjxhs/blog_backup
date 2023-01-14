---
title: 下一代镜像构建工具 Earthly
date: 2021-11-01 10:06:09
tags:
---
### 一、Earthly 介绍

![](/img/newimg/008i3skNgy1gvzfb9c3jxj30u00fgq48.jpg)

Earthly 是一个更加高级的 Docker 镜像构建工具，Earthly 通过自己定义的 Earthfile 来代替传统的 Dockerfile 完成镜像构建；Earthfile 就如同 Earthly 官方所描述:
Makefile + Dockerfile = Earthfile
在使用 Earthly 进行构建镜像时目前强依赖于 buildkit，Earthly 通过 buildkit 支持了一些 Dockerfile  的扩展语法，同时将 Dockerfile 与 Makefile 整合，使得多平台构建和代码化 Dockerfile 变得更加简单；使用  Earthly 可以更加方便的完成 Dockerfile 的代码复用以及更加友好的 CI 自动集成。

### 二、快速开始

#### 安装依赖

Earthly 目前依赖于 Docker 和 Git，所以安装 Earthly 前请确保机器已经安装了 Docker 和 Git。

#### 安装 Earthly

Earthly 采用 Go 编写，所以主要就一个二进制文件，Linux 下安装可以直接参考官方的安装脚本:

```
$ sudo /bin/sh -c 'wget https://github.com/earthly/earthly/releases/latest/download/earthly-linux-amd64 -O /usr/local/bin/earthly && chmod +x /usr/local/bin/earthly && /usr/local/bin/earthly bootstrap --with-autocomplete'
```
安装完成后 Earthly 将会启动一个 buildkitd 容器: `earthly-buildkitd`。

#### 语法高亮

目前 Earthly 官方支持 VS Code、VIM 以及 Sublime Text 三种编辑器的语法高亮，具体如何安装请参考 官方文档[1]。
#### 基本使用

本示例源于官方 Basic 教程，以下示例以编译 Go 项目为样例:
首先创建一个任意名称的目录，目录中存在项目源码文件以及一个 `Earthfile` 文件；
`main.go`
```
package main

import "fmt"

func main() {
    fmt.Println("hello world")
}
```

`Earthfile`

```
FROM golang:1.17-alpine
WORKDIR /go-example

build:
    COPY main.go .
    RUN go build -o build/go-example main.go
    SAVE ARTIFACT build/go-example /go-example AS LOCAL build/go-example

docker:
    COPY +build/go-example .
    ENTRYPOINT ["/go-example/go-example"]
    SAVE IMAGE go-example:latest
```

有了 `Earthfile` 以后我们就可以使用 `Earthly` 将其打包为镜像；

```
# 目录结构
~/t/earthlytest ❯❯❯ tree
.
├── Earthfile
└── main.go

0 directories, 2 files

# 通过 earthly 进行构建
~/t/earthlytest ❯❯❯ earthly +docker
```
![](/img/newimg/008i3skNgy1gvzfdth8m9j30u00j7dj3.jpg)


构建完成后我们就可以直接从 docker 的 images 列表中查看刚刚构建的镜像，并运行:

![](/img/newimg/008i3skNgy1gvzfe16dhuj30u00b0wfu.jpg)

### 三、进阶使用

#### 多阶段构建

Earthfile 中包含类似 Makefile 一样的 target，不同的 target 之间还可以通过特定语法进行引用，每个 target 都可以被单独执行，执行过程中 earthly 会自动解析这些依赖关系。
这种多阶段构建时语法很弹性，我们可以在每个阶段运行独立的命令以及使用不同的基础镜像；从快速开始中可以看到，我们始终使用了一个基础镜像(golang:1.17-alpine)，对于 Go 这种编译后自带运行时不依赖其语言 SDK 的应用，我们事实上可以将 “发布物” 仅放在简单的运行时系统镜像内，从而减少最终镜像体积:
![](/img/newimg/008i3skNgy1gvzfej5tooj30u00f1q3z.jpg)

由于使用了多个 target，所以我们可以单独的运行 build 这个 target 来验证我们的编译流程，这种多 target 的设计方便我们构建应用时对编译、打包步骤的细化拆分，同时也方便我们进行单独的验证。 例如我们单独执行 build 这个 target 来验证我们的编译流程是否正确:

![](/img/newimg/008i3skNgy1gvzfeusb76j30u00jxgo6.jpg)
在其他阶段验证完成后，我们可以直接运行最终的 target，earthly 会自动识别到这种依赖关系从而自动运行其依赖的 target:

![](/img/newimg/008i3skNgy1gvzff0xktxj30u00hkdio.jpg)

#### 扩展指令

##### SAVE

SAVE 指令是 Earthly 自己的一个扩展指令，实际上分为 SAVE ARTIFACT 和 SAVE IMAGE；其中 SAVE ARTIFACT 指令格式如下:

```
SAVE ARTIFACT [--keep-ts] [--keep-own] [--if-exists] [--force] <src> [<artifact-dest-path>] [AS LOCAL <local-path>]
```

> SAVE ARTIFACT 指令用于将文件或目录从 build 运行时环境保存到 target 的 artifact 环境；当保存到 artifact 环境后，可以通过 COPY 等命令在其他位置进行引用，类似于 Dockerfile 的 COPY --from... 语法；不同的是 SAVE ARTIFACT 支持 AS LOCAL <local-path> 附加参数，一但指定此参数后，earthly 会同时将文件或目录在宿主机复制一份，一般用于调试等目的。SAVE ARTIFACT 命令在上面的样例中已经展示了，在运行完 earthly +build 命令后实际上会在本地看到被 SAVE 出来的 ARTIFACT:

![](/img/newimg/008i3skNgy1gvzffup6pmj30u00g9wfr.jpg)

而另一个 SAVE IMAGE 指令则主要用于将当前的 build 环境 SAVE 为一个 IMAGE，如果指定了 --push 选项，同时在执行 earthly +target 命令时也加入 --push 选项，该镜像将会自动被推送到目标 Registry 上。SAVE IMAGE 指令格式如下:
```
SAVE IMAGE [--cache-from=<cache-image>] [--push] <image-name>...
```

![](/img/newimg/008i3skNgy1gvzfg4swbxj30u00gr0um.jpg)

##### GIT CLONE

GIT CLONE 指令用于将指定 git 仓库 clone 到 build 环境中；与 RUN git clone... 命令不同的是，GIT CLONE 通过宿主机的 git 命令运行，它不依赖于容器内的 git 命令，同时还可以直接为 earthly 配置 git 认证，从而避免将这些安全信息泄漏到 build 环境中； 关于如何配置 earthly 的 git 认证请参考 官方文档[2]；下面是 GIT CLONE 指令的样例:


![](/img/newimg/008i3skNgy1gvzfh5dcc9j30u00hs419.jpg)

##### COPY

COPY 指令与标准的 Dockerfile COPY 指令类似，除了支持 Dockerfile 标准的 COPY 功能以外，earthly 中的 COPY 指令可以引用其他 target 环节产生的 artifact，在引用时会自动声明依赖关系；即当在 B target 中存在 COPY +A/xxxxx /path/to/copy 类似的指令时，如果只单纯的执行 earthly +B，那么 earthly 根据依赖分析会得出在 COPY 之前需要执行 target A。COPY 指令的语法格式如下:

```
# 与 Dockerfile 相同的使用方式，从上下文复制
COPY [options...] <src>... <dest>

# 扩展支持的从 target 复制方式
COPY [options...] <src-artifact>... <dest>
```

##### RUN

RUN 指令在标准使用上与 Dockerfile 里保持一致，除此之外增加了更多的扩展选项，其指令格式如下:

```

# shell 方式运行(/bin/sh -c)
RUN [--push] [--entrypoint] [--privileged] [--secret <env-var>=<secret-ref>] [--ssh] [--mount <mount-spec>] [--] <command>

# exec 方式运行
RUN [[<flags>...], "<executable>", "<arg1>", "<arg2>", ...]
```
其中 --privileged 选项允许运行的命令使用 privileged capabilities，但是需要 earthly 在运行 target 时增加 --allow-privileged 选项；--interactive / --interactive-keep 选项用于交互式执行一些命令，在完成交互后 build 继续进行，在交互过程中进行的操作都会被持久化到 镜像中:

![](/img/newimg/008i3skNgy1gvzfi2c9gnj30u00j2whc.jpg)

##### UDCS

UDCs 全称 “User-defined commands”，即用户定义指令；通过 UDCs 我们可以将 Earthfile 中特定的命令剥离出来，从而实现更加通用和统一的代码复用；下面是一个定义 UDCs 指令的样例:
```
# 定义一个 Command
# ⚠️ 注意: 语法必须满足以下规则
# 1、名称全大写
# 2、名称下划线分割
# 3、首个命令必须为 COMMAND(后面没有冒号)
MY_COPY:
    COMMAND
    ARG src
    ARG dest=./
    ARG recursive=false
    RUN cp $(if $recursive =  "true"; then printf -- -r; fi) "$src" "$dest"

# target 中引用
build:
    FROM alpine:3.13
    WORKDIR /udc-example
    RUN echo "hello" >./foo
    # 通过 DO 关键字引用 UDCs
    DO +MY_COPY --src=./foo --dest=./bar
    RUN cat ./bar # prints "hello"
```

UDCs 不光可以定义在一个 Earthfile 中，UDCs 可以跨文件、跨目录引用:

![](/img/newimg/008i3skNgy1gvzfigy9x7j30u00ka0v0.jpg)
有了 UDCs 以后，我们可以通过这种方式将对基础镜像的版本统一控制、对特殊镜像的通用处理等操作全部抽象出来，然后每个 Earthfile 根据需要进行引用；关于 UDCs 的使用样例可以参考我的 autobuild[4] 项目，其中的 udcs[5] 目录定义了大量的通用 UDCs，这些 UDCs 被其他目标镜的 Earthfile 批量引用。

#### 多平台构建

在以前使用 Dockerfile 的时候，我们需要自己配置然后开启 buildkit 来实现多平台构建；在配置过程中可能会很繁琐，现在使用 earthly 可以默认帮我们实现多平台的交叉编译，我们需要做的仅仅是在 Earthfile 中声明需要支持哪些平台而已:

![](/img/newimg/008i3skNgy1gvzfj3fdekj30u00bnq3m.jpg)

以上 Earthfile 在执行 earthly --push +all 构建时，将会自动构建四个平台的镜像，并保持单个 tag，同时由于使用了 --push 选项还会自动推送到 Docker Hub 上:

![](/img/newimg/008i3skNgy1gvzfj8slg2j30u00n80uc.jpg)

### 总结

Earthly 弥补了 Dockerfile 的很多不足，解决了很多痛点问题；但同样可能需要一些学习成本，但是如果已经熟悉了 Dockerfile  其实学习成本不高；所以目前还是比较推荐将 Dockerfile 切换为 Earthfile  进行统一和版本化管理的。本文由于篇幅所限(懒)很多地方没有讲，比如共享缓存等，所以关于 Earthly 更多的详细使用等最好还是仔细阅读一下官方文档[6]。


##### 引用链接

```
官方文档: https://earthly.dev/get-earthly
官方文档: https://docs.earthly.dev/docs/guides/auth
Earthfile reference: https://docs.earthly.dev/docs/earthfile
autobuild: https://github.com/mritd/autobuild
udcs: https://github.com/mritd/autobuild/tree/main/earthfiles/udcs
官方文档: https://docs.earthly.dev/docs/guides
```