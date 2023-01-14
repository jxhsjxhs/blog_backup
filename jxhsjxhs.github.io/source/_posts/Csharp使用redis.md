---
title: Csharp使用redis
date: 2020-06-02 16:16:47
tags:
---

在redis中常用`StackExchange.Redis`库
使用`NuGet`安装`StackExchange.Redis`
简单使用方法
```
using System;
using  StackExchange.Redis;

namespace redistest
{
    class Program
    {
        static void Main(string[] args)
        {
            //配置连接
            var conn = ConnectionMultiplexer.Connect("ss.jxhs.me:6379");
            
            //获取连接
            IDatabase idb = conn.GetDatabase(1); // 默认db0

            //获取字符串
            string city =  idb.StringGet("hello");
            
            //塞数据进redis
            string value = "abcdefg";
            idb.StringSet("mykey", value);
        }
    }
}
```

### 推荐一个redis的客户端。贼好用 
![](/img/newimg/007S8ZIlgy1gfez9d29hhj30uk0k8ac6.jpg)
[redis工具github项目地址](https://github.com/qishibo/AnotherRedisDesktopManager)

### StackExchange.Redis具体使用文档
[StackExchange.Redis库中文文档](https://www.jxhs.me/db/redis-csharp.pdf)