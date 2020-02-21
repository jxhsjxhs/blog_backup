---
title: 使用 Cobra 构建命令行工具
date: 2020-02-21 21:11:57
tags:
---


Cobra既是用于创建强大的现代CLI应用程序的库，也是用于生成应用程序和命令文件的程序。

有多强呢,我列举一下优秀的开源项目中用到Cobra的
```
Kubernetes
Hugo
rkt
etcd
Moby (former Docker)
Docker (distribution)
OpenShift
Delve
GopherJS
CockroachDB
Bleve
ProjectAtomic (enterprise)
GiantSwarm's swarm
Nanobox/Nanopack
rclone
nehm
Pouch
```
### 概念介绍
Cobra 结构由三部分组成：命令 (commands)、参数 (arguments)、标志 (flags)。基本模型如下：
`APPNAME VERB NOUN --ADJECTIVE` 或者 `APPNAME COMMAND ARG --FLAG`
如果不是太理解的话，没关系，我们先看个例子：
```
hugo server --port=1313
```
hugo：根命令
server：子命令
–port：标志

再看个带有参数的例子：
```
git clone URL --bare
```
git：根命令
clone：子命令
URL：参数，即 clone 作用的对象
–bare：标志

总结如下：

> commands 代表行为，是应用的中心点
> arguments 代表行为作用的对象
> flags 是行为的修饰符


### 主要功能

cobra 的主要功能如下，可以说每一项都很实用：

```
简易的子命令行模式，如 app server， app fetch 等等
完全兼容 posix 命令行模式
嵌套子命令 subcommand
支持全局，局部，串联 flags
使用 cobra 很容易的生成应用程序和命令，使用 cobra create appname 和 cobra add cmdname
如果命令输入错误，将提供智能建议，如 app srver，将提示 srver 没有，是不是 app server
自动生成 commands 和 flags 的帮助信息
自动生成详细的 help 信息，如 app help
自动识别帮助 flag -h，--help
自动生成应用程序在 bash 下命令自动完成功能
自动生成应用程序的 man 手册
命令行别名
自定义 help 和 usage 信息
可选的与 viper apps 的紧密集成
```
上面的描述稍微有点抽象，下面结合例子讲下cobra如何做的。
### Cobra的安装
首先，通过go get下载cobra
```
go get -v github.com/spf13/cobra/cobra
go install
完成安装 (GOROOT/bin/记得加到环境变量)
```
### 初始化项目

在命令行下运行下cobra命令
![](https://tva1.sinaimg.cn/large/0082zybpgy1gc4duaem93j319c0qa13s.jpg)
如图的话 就是安装OK了。接下来就可以使用cobra了。
假设我们现在要开发一个基于CLI的命令程序，名字的。如下dsb(大傻逼)图操作：
```
➜  src cobra init dsb --pkg-name=dsb
Your Cobra applicaton is ready at
/Users/jame_xhs/go/src/dsb
```
当前目录结构为
```
dsb
├── cmd
│   └── root.go
├── LICENSE
└── main.go
```
可以看到初始化后的项目非常简单，主要是 main.go 和 root.go 文件。在编写代码之前，我们先分析下目前代码的逻辑。

### 代码分析
先查看下入口文件 `main.go`。代码逻辑很简单，就是调用 cmd 包里 Execute()函数:

```
package main

import "demo/cmd"

func main() {
  cmd.Execute()
}
```
再看下 `root.go` 中 rootCmd 的字段：
```
...

var rootCmd = &cobra.Command{
  Use:   "demo",
  Short: "A brief description of your application",
  Long: `A longer description that spans multiple lines and likely contains
examples and usage of using your application. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.`,
  // Uncomment the following line if your bare application
  // has an action associated with it:
  //    Run: func(cmd *cobra.Command, args []string) { },
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
  if err := rootCmd.Execute(); err != nil {
    fmt.Println(err)
    os.Exit(1)
  }
}

...

```

简单说明：
Use：命令名
Short & Long：帮助信息的文字内容
Run：运行命令的逻辑

Command 结构体中的字段当然远不止这些，受限于篇幅，这里无法全部介绍。有兴趣的童鞋可以查阅下官方文档。

运行测试：
```
[root@localhost demo]# go run main.go
A longer description that spans multiple lines and likely contains
examples and usage of using your application. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.

subcommand is required
exit status 1
```
如果运行的结果和我的一致，那我们就可以进入到实践环节了。
## 实践

### 子命令
之前运行会提示 subcommand is required，是因为根命令无法直接运行。那我们就添加个子命令试试。
通过 cobra add 添加子命令 create:
![](https://tva1.sinaimg.cn/large/0082zybpgy1gc4f8adl5mj30mo03et8p.jpg)

当前项目结构为：
dsb
├── cmd
│   ├── create.go
│   └── root.go
├── LICENSE
└── main.go
查看下 create.go，init() 说明了命令的层级关系:

```
...

func init() {
       rootCmd.AddCommand(createCmd)        
}
```

运行测试：

```
[root@localhost demo]# go run main.go create
create called

# 未知命令
[root@localhost demo]# go run main.go crea
Error: unknown command "crea" for "demo"

Did you mean this?
	create

Run 'demo --help' for usage.
unknown command "crea" for "demo"

Did you mean this?
	create
```
![](https://tva1.sinaimg.cn/large/0082zybpgy1gc4fdq8cxxj30j60ekq3d.jpg)

### 子命令嵌套
对于功能相对复杂的 CLI，通常会通过多级子命令，即：子命令嵌套的方式进行描述，那么该如何实现呢？
```
dsb create rule
```

首先添加子命令 rule :

```
[root@localhost dsb]# cobra add rule
rule created at /root/go/src/dsb
```

当前目录结构如下：

```
dsb
├── cmd
│   ├── create.go
│   ├── root.go
│   └── rule.go
├── LICENSE
└── main.go
```

目前create 和 rule 是同级的，所以需要修改 rule.go 的 init() 来改变子命令间的层级关系

```
...

func init() {
        // 修改子命令的层级关系
        //rootCmd.AddCommand(ruleCmd)
        createCmd.AddCommand(ruleCmd)
}
```
这样 rule 就属于create的子命令了。
虽然调整了命令的层级关系，但是目前运行 demo create 会打印 create called，我希望运行时可以打印帮助提示。所以我们继续完善下代码，修改 create.go：
```
...

var createCmd = &cobra.Command{
        Use:   "create",
        Short: "create",
        Long: "Create Command.",
        Run: func(cmd *cobra.Command, args []string) {
                // 如果 create 命令后没有参数，则提示帮助信息
                if len(args) == 0 {
                  cmd.Help()
                  return
                }
        },
}

...

```

运行测试：

直接运行 create，打印帮助提示：
![](https://tva1.sinaimg.cn/large/0082zybpgy1gc4fi34sm4j310e0koq4y.jpg)

运行 `create rule`，输出 `rule called`：
```
[root@localhost dsb]# go run main.go create rule
rule called
```

### 参数
先说说参数。现在有个需求：给 CLI 加个位置参数，要求参数有且仅有一个。这个需求我们要如何实现呢？
```
dsb create rule foo 
```
实现前先说下，Command 结构体中有个 Args 的字段，接受类型为 `type PositionalArgs func(cmd *Command, args []string) error`

内置的验证方法如下：

> NoArgs：如果有任何参数，命令行将会报错
> ArbitraryArgs： 命令行将会接收任何参数
> OnlyValidArgs： 如果有如何参数不属于 Command 的 ValidArgs 字段，命令行将会报错
> MinimumNArgs(int)： 如果参数个数少于 N 个，命令行将会报错
> MaximumNArgs(int)： 如果参数个数多于 N 个，命令行将会报错
> ExactArgs(int)： 如果参数个数不等于 N 个，命令行将会报错
> RangeArgs(min, max)： 如果参数个数不在 min 和 max 之间, 命令行将会报错


由于需求里要求参数有且仅有一个，想想应该用哪个内置验证方法呢？ ExactArgs(int)。
改写下 `rule.go`：
```
...

var ruleCmd = &cobra.Command{
        Use:   "rule",
        Short: "rule",
        Long: "Rule Command.",
        
        Args: cobra.ExactArgs(1),
        Run: func(cmd *cobra.Command, args []string) {           
          fmt.Printf("Create rule %s success.\n", args[0])
        },
}

...

```

运行测试：

不输入参数：

```
[root@localhost dsb]# go run main.go create rule
Error: accepts 1 arg(s), received 0
```

输入 1 个参数：
```
[root@localhost dsb]# go run main.go create rule foo
Create rule foo success.
```

输入 2 个参数：
```
[root@localhost dsb]# go run main.go create rule
Error: accepts 1 arg(s), received 2
```
从测试的情况看，运行的结果符合我们的预期。如果需要对参数进行复杂的验证，还可以自定义 Args，这里就不多做赘述了。

### 标志

再说说标志。现在要求 CLI 不接受参数，而是通过标志 --name 对 rule 进行描述。这个又该如何实现？

```
demo create rule --name foo
```

Cobra 中有两种标志：持久标志 ( Persistent Flags ) 和 本地标志 ( Local Flags ) 。

> 持久标志：指所有的 commands 都可以使用该标志。比如：–verbose ，–namespace
> 本地标志：指特定的 commands 才可以使用该标志。



这个标志的作用是修饰和描述 rule的名字，所以选用本地标志。修改 rule.go：

```
package cmd

import (
        "fmt"        
        "github.com/spf13/cobra"
)       

// 添加变量 name
var name string

var ruleCmd = &cobra.Command{
        Use:   "rule",
        Short: "rule",
        Long: "Rule Command.",
        Run: func(cmd *cobra.Command, args []string) {
          // 如果没有输入 name
          if len(name) == 0 {
            cmd.Help()
            return
          }     
          fmt.Printf("Create rule %s success.\n", name)
        },
}

func init() {
        createCmd.AddCommand(ruleCmd)
        // 添加本地标志
        ruleCmd.Flags().StringVarP(&name, "name", "n", "", "rule name")

```
说明：`StringVarP` 用来接收类型为字符串变量的标志。相较`StringVar`， `StringVarP` 支持标志短写。以我们的 CLI 为例：在指定标志时可以用 `--name`，也可以使用短写 `-n`。

运行测试：

```
# 这几种写法都可以执行
[root@localhost dsb]# go run main.go create rule -n foo
Create rule foo success.
[root@localhost dsb]# go run main.go create rule --name foo
Create rule foo success.
[root@localhost dsb]# go run main.go create -n foo rule
Create rule foo success.
```

### 读取配置
需求：要求 --name 标志存在默认值，且该值是可配置的。
如果只需要标志提供默认值，我们只需要修改 StringVarP 的 value 参数就可以实现。但是这个需求关键在于标志是可配置的，所以需要借助配置文件。

很多情况下，CLI 是需要读取配置信息的，比如 kubectl 的~/.kube/config。在帮助提示里可以看到默认的配置文件为 $HOME/.demo.yaml：
```
Global Flags:
      --config string   config file (default is $HOME/.demo.yaml)
```

​配置库我们可以使用 Viper。Viper 是 Cobra 集成的配置文件读取库，支持 `YAML`，`JSON`， `TOML`， `HCL` 等格式的配置。

添加配置文件 $HOME/.demo.yaml，增加 name 字段：
```
[root@localhost ~]# vim $HOME/.demo.yaml 
name: xiangli
```

修改 `rule.go`:

```
package cmd

import (
        "fmt"
         // 导入 viper 包
        "github.com/spf13/viper"
        "github.com/spf13/cobra"
)

var name string

var ruleCmd = &cobra.Command{
        Use:   "rule",
        Short: "rule",
        Long: "Rule Command.",
        Run: func(cmd *cobra.Command, args []string) {
          // 不输入 --name 从配置文件中读取 name
          if len(name) == 0 {
            name = viper.GetString("name")
            // 配置文件中未读取到 name，打印帮助提示
            if len(name) == 0 {
              cmd.Help()
              return
            }
          }
          fmt.Printf("Create rule %s success.\n", name)
        },
}

func init() {
        createCmd.AddCommand(ruleCmd)
        ruleCmd.Flags().StringVarP(&name, "name", "n", "", "rule name")
}
```

运行测试：


```
[root@localhost dsb]# go run main.go create rule
Using config file: /root/.demo.yaml
Create rule xiangli success.
```

如果 CLI 没有用到配置文件，可以在初始化项目的时候关闭 Viper 的选项以减少编译后文件的体积，如下：
```
cobra init demo --pkg-name=demo --viper=false
```

### 编译运行
​编译生成命令行工具
```
[root@localhost dsb]# go build -o dsb
```

运行测试：

```
[root@localhost dsb]# ./dsb create rule
Using config file: /root/.demo.yaml
Create rule xiangli success.
```

学起来啊,同学们。