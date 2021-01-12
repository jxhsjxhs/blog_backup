---
title: RabbitMQ Golang之HelloWorld
date: 2021-01-08 22:20:59
tags:
---
本文翻译自RabbitMQ官网的Go语言客户端系列教程，共分为六篇，本文是第一篇——HelloWorld。

这些教程涵盖了使用RabbitMQ创建消息传递应用程序的基础知识。 你需要安装RabbitMQ服务器才能完成这些教程，请参阅安装指南或使用Docker镜像。 这些教程的代码是开源的，官方网站也是如此。


### <center>先决条件 </center>
本教程假设RabbitMQ已安装并运行在本机上的标准端口（5672）。如果你使用不同的主机、端口或凭据，则需要调整连接设置。


###  <center>RabbitMQ Go语言客户端教程（一） </center>

#### 介绍
RabbitMQ是一个消息代理：它接受并转发消息。你可以把它想象成一个邮局：当你把你想要邮寄的邮件放进一个邮箱时，你可以确定邮差先生或女士最终会把邮件送到你的收件人那里。在这个比喻中，RabbitMQ是一个邮箱、一个邮局和一个邮递员。

RabbitMQ和邮局的主要区别在于它不处理纸张，而是接受、存储和转发二进制数据块——消息。

RabbitMQ和一般的消息传递都使用一些术语。

> 生产仅意味着发送。发送消息的程序是生产者：
![](https://tva1.sinaimg.cn/large/008eGmZEgy1gmgnk1d1gnj301z01fdfl.jpg)

> 队列是位于RabbitMQ内部的邮箱的名称。尽管消息通过RabbitMQ和你的应用程序流动，但它们只能存储在队列中。队列只受主机内存和磁盘限制的限制，实际上它是一个大的消息缓冲区。许多生产者可以向一个队列发送消息，而许多消费者可以尝试从一个队列接收数据。以下是我们表示队列的方式：

![](https://tva1.sinaimg.cn/large/008eGmZEgy1gmgnk9o4loj303m02j0ol.jpg)

> 消费与接收具有相似的含义。消费者是一个主要等待接收消息的程序：
![](https://tva1.sinaimg.cn/large/008eGmZEgy1gmgnki4ehmj301z01fjr5.jpg)
请注意，生产者，消费者和代理（broker）不必位于同一主机上。实际上，在大多数应用程序中它们不是。一个应用程序既可以是生产者，也可以是消费者。

