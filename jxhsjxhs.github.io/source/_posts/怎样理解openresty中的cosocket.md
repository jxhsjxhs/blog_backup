---
title: 怎样理解openresty中的cosocket
date: 2020-12-01 15:22:35
tags:
---

cosocket 是各种 lua-resty-* 非阻塞库的基础，没 有 cosocket，开发者就无法用 Lua 来快速连接各种外部的网络服务。

在早期的 OpenResty 版本中，如果想要去与 Redis、memcached 这些服务交互的话，需要使用 redis2-nginx-module、redis-nginx-module 和 memc-nginx-module这些 C 模块.这些模块至今仍然在 OpenResty 的发行包中。

cosocket 功能加入以后，它们都已经被 lua-resty-redis 和 lua-resty-memcached 替代，基 本上没人再去使用 C 模块连接外部服务了。

### 什么是 cosocket
cosocket是 OpenResty 中的专有名词，是把协程和网络套接字的英文 拼在一起形成的，即 cosocket = coroutine + socket。所以，可以把 cosocket 翻译为“协程套接字”。

cosocket 不仅需要 Lua 协程特性的支持，也需要 Nginx 中非常重要的事件机制的支持，这两者结合在一 起，最终实现了非阻塞网络 I/O。另外，cosocket 支持 TCP、UDP 和 Unix Domain Socket。

在 OpenResty 中调用一个 cosocket 相关函数，内部实现便是下面这张图的样子：
![](https://tva1.sinaimg.cn/large/0081Kckwgy1glrwdfkpjvj30ye0fkjuz.jpg)
用户的 Lua 脚本每触发一个网络操作，都会有协程的 yield 以及 resume。

遇到网络 I/O 时，它会交出控制权（yield），把网络事件注册到 Nginx 监听列表中，并把权限交给 Nginx；当有 Nginx 事件达到触发条件时，便唤醒对应的协程继续处理（resume）。

OpenResty 正是以此为基础，封装实现 connect、send、receive 等操作，形成了现在的 cosocket API。以处理 TCP 的 API 为例来介绍一下。处理 UDP 和 Unix Domain Socket ，与TCP 的接口基 本是一样的。


### cosocket API 和指令简介
TCP 相关的 cosocket API 可以分为下面这几类：
> 创建对象：ngx.socket.tcp。
> 设置超时：tcpsock:settimeout 和 tcpsock:settimeouts。
> 建立连接：tcpsock:connect。
> 发送数据：tcpsock:send。
> 接受数据：tcpsock:receive、tcpsock:receiveany 和 tcpsock:receiveuntil。
> 连接池：tcpsock:setkeepalive。
> 关闭连接：tcpsock:close。

这些 API 可以使用的上下文：
```
	
rewrite_by_lua*, access_by_lua*, content_by_lua*, ngx.timer.*, ssl_certificate_by_lua*, ssl_session_fetch_by_lua*_
```

由于 Nginx 内核的各种限制，cosocket API 在 set_by_lua*， log_by_lua*， header_filter_by_lua* 和 body_filter_by_lua* 中是无法使用的。而在 init_by_lua* 和 init_worker_by_lua* 中暂时也不能用，不过 Nginx 内核对这两个阶段并没有限制。

此外，与这些 API 相关的，还有 8 个 lua_socket_ 开头的 Nginx 指令：

> lua_socket_connect_timeout：连接超时，默认 60 秒。
> lua_socket_send_timeout：发送超时，默认 60 秒。
> lua_socket_send_lowat：发送阈值（low water），默认为 0。
> lua_socket_read_timeout： 读取超时，默认 60 秒。
> lua_socket_buffer_size：读取数据的缓存区大小，默认 4k/8k。
> lua_socket_pool_size：连接池大小，默认 30。
> lua_socket_keepalive_timeout：连接池 cosocket 对象的空闲时间，默认 60 秒。
> lua_socket_log_errors：cosocket 发生错误时，是否记录日志，默认为 on。

有些指令和 API 的功能一样的，比如设置超时时间和连接池大小等。不过，如果两者有冲突的话，API 的优先级高于指令，会覆盖指令设置的值。所以，一般来说，都推荐使用 API来做设 置，这样也会更加灵活。 

通过一个具体的例子，来理解如何使用这些 cosocket API。发送 TCP 请求到一个网站，并把返回的内容打印出来：

```
resty -e 'local sock = ngx.socket.tcp()
    sock:settimeout(1000) -- one second timeout
    local ok, err = sock:connect("www.baidu.com", 80)
    if not ok then
        ngx.say("failed to connect: ", err)
        return
    end
local req_data = "GET / HTTP/1.1\r\nHost: www.baidu.com\r\n\r\n"
local bytes, err = sock:send(req_data)
if err then
    ngx.say("failed to send: ", err)
    return
end
local data, err, partial = sock:receive()
if err then
    ngx.say("failed to receive: ", err)
    return
end
sock:close()
ngx.say("response is: ", data)
```

分析下这段代码:
> 首先，通过 ngx.socket.tcp() ，创建 TCP 的 cosocket 对象，名字是 sock。
> 然后，使用 settimeout() ，把超时时间设置为 1 秒。注这里的超时没有区分 connect、receive，是统一的设置。
> 接着，使用 connect() 去连接指定网站的 80 端口，如果失败就直接退出。
> 连接成功的话，就使用 send() 来发送构造好的数据，如果发送失败就退出。
> 发送数据成功的话，就使用 receive() 来接收网站返回的数据。这里 receive() 的默认参数值是 *l，也就是只返回第一行的数据；如果参数设>置为了*a，就是持续接收数据，直到连接关闭；
> 最后，调用 close() ，主动关闭 socket 连接。

接 下来，我们对这个示例再做一些调整:
第一个动作，对 socket 连接、发送和读取这三个动作，分别设置超时时间。

settimeout() 作用是把超时时间统一设置为一个值。如果要想分开设置，就需要使用 settimeouts() 函数，比如下面这样的写法：
```
sock:settimeouts(1000, 2000, 3000)
```
表示连接超时为 1 秒，发送超时为 2 秒，读取超时为 3 秒。在OpenResty 和 lua-resty 库中，大部分和时间相关的 API 的参数，都以毫秒为单位


第二个动作，receive接收指定大小的内容。

receive() 接口可以接收一行数据，也可以持续接收数据。如果只想接收 10K 大小的数据，应该使用receiveany() ，它就是专为满足这种需求而设计的
```
local data, err, partial = sock:receiveany(10240)
```
关于receive，还有另一个很常见的用户需求，那就是一直获取数据，直到遇到指定字符串才停止。

receiveuntil() 专门用来解决这类问题，它不会像 receive() 和 receiveany() 一样返回字符串， 而会返回一个迭代器。这样就可以在循环中调用它来分段读取匹配到的数据，当读取完毕时，就会返回 nil。

```
local reader = sock:receiveuntil("\r\n")
while true do
    local data, err, partial = reader(4)
    if not data then
        if err then
            ngx.say("failed to read the data stream: ", err)
            break
        end
        ngx.say("read done")
        break
    end
    ngx.say("read chunk: [", data, "]")
end
```
receiveuntil 会返回 \r\n 之前的数据，并通过迭代器每次读取其中的 4 个字节，


第三个动作，不直接关闭 socket，而是放入连接池中。

没有连接池的话，每次请求进来都要新建一个连接，就会导致 cosocket 对象被频繁地创建和销 毁，造成不必要的性能损耗。

为了避免这个问题，在使用完一个 cosocket 后，可以调用 setkeepalive() 放到连接池中
```
local ok, err = sock:setkeepalive(2 * 1000, 100)
if not ok then
    ngx.say("failed to set reusable: ", err)
end   
```

这段代码设置了连接的空闲时间为 2 秒，连接池的大小为 100。这样，在调用 connect() 函数时，就会优先从连接池中获取 cosocket 对象。

关于连接池的使用，有两点需要注意：

第一，不能把发生错误的连接放入连接池，否则下次使用时，就会导致收发数据失败。这也是为什么需要判断每一个 API 调用是否成功的一个原因。

第二，要搞清楚连接的数量。连接池是 worker 级别的，每个 worker 都有自己的连接池。所以，如果有 10 个 worker，连接池大小设置为 30，那么对于后端的服务来讲，就等于有 300个连接。