---
title: tcp/ip之TCP Fast open
date: 2020-02-20 12:08:10
tags:
---

### 产生背景
Google研究发现TCP三次握手是页面延迟时间的重要组成部分，所以他们提出了TFO(TCP Fast Open)：在TCP握手期间交换数据，这样可以减少一次RTT。根据测试数据，TFO可以减少15%的HTTP传输延迟，全页面的下载时间平均节省10%，最高可达40%。

(RTT指的是往返时延。在计算机网络中它是一个重要的性能指标，表示从发送端发送数据开始，到发送端收到来自接收端的确认（接收端收到数据后便立即发送确认），总共经历的时延。)

### 实现原理
TFO允许在TCP握手期间发送和接收初始SYN分组中的数据。如果客户端和服务器都支持TFO功能，则可以减少建立到同一服务器的多个TCP连接的延迟。这是通过在初始TCP握手之后在客户端上存储TFO cookie来实现的。如果客户端稍后重新连接，则此TFO cookie将发送到服务器，从而允许连续的TCP握手跳过一个往返延迟，从而减少延迟。



### 拓扑图
普通的TCP连接过程如下图所示 
![](/img/newimg/0082zybpgy1gc2s4f800fj30go08zwem.jpg)



而TFO的连接过程如下 
![](/img/newimg/0082zybpgy1gc2s5lu0yij30go099dg0.jpg)
当客户端断开一段时间后，再次连接过程如下
![](/img/newimg/0082zybpgy1gc2s5whhzuj30go0ac3yr.jpg)
可以看出使用TFO后，非第一次连接变成了两次握手即可

总揽
![](/img/newimg/0082zybpgy1gc2pyjnhaoj30ry0nedis.jpg)

### TFO的开启

TFO功能在Linux 3.7 内核中开始集成，因此RHEL7/CentOS7是支持的，但默认没有开启，使用以下方式开启：
```
echo 3 > /proc/sys/net/ipv4/tcp_fastopen
#3的意思是开启TFO客户端和服务器端
#1表示开启客户端，2表示开启服务器端
```
除了内核的支持，应用程序也要开启支持，例如nginx（1.5.8+）开启方法如下：
```
server {
        listen 80 backlog=4096 fastopen=256 default;
        server_name _;
```