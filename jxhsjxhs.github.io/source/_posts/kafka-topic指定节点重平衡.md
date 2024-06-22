---
title: kafka topic指定节点重平衡
date: 2024-06-22 17:13:20
tags:
index_img: /img/newimg/2024-06-22-02.png
banner_img: /img/newimg/2024-06-22-02.png
---

### 背景：

业务预估，某个业务所用的几个topic数据量 以及io会非常大，需要增加更多的broker来支撑。这时就有两种方案，
> 第一种：这些特殊需求的topic独享几个broker。而其他的topic不动。
> 
> 第二种：新增broker后，可以简单粗暴的将topic的partition数量设置大一些，并且设置随机重平衡。让kafka调度器去做区分。

在实际生产环境中，第一种方式是对其他topic影响最小，并且最符合稳定性要求的方案。图示如下

![](/img/newimg/2024-06-22-02.png)

### 迁移操作步骤如下：
#### 1、首先查看kafka集群的broker信息确保迁移的broker已经加入集群
```
本实验环境有七个broker，分别是0、1、2、3、4、5、6，其中1、2、3三个节点有zooKeeper。
/data/zookeeper/bin/zkCli.sh
[zk: localhost:2181(CONNECTED) 0] ls /brokers/ids
[0, 1, 2, 3, 4, 5, 6]
```
![](/img/newimg/2024-06-22-03.png)


#### 2、查看topic分区的ISR，确保topic的Leader、Replicas、ISR参数正常，确保ISR同步队列正常。
```
root@kafka-2:~# /data/kafka/bin/kafka-topics.sh --describe --topic my-topic --bootstrap-server 192.168.1.231:9092
Topic: my-topic	TopicId: 1FtXs5m8TMyjC18Qjs3ttg	PartitionCount: 3	ReplicationFactor: 3	Configs: segment.bytes=1073741824
	Topic: my-topic	Partition: 0	Leader: 0	Replicas: 0,1,2	Isr: 0,1,2
	Topic: my-topic	Partition: 1	Leader: 1	Replicas: 1,2,0	Isr: 0,1,2
	Topic: my-topic	Partition: 2	Leader: 1	Replicas: 2,1,0	Isr: 1,2,0
```
![](/img/newimg/2024-06-22-04.png)
#### 3、如果数据量特别大，可以提前设置好topic数据保存时间，可以加快迁移速度。
```
# 得研发确认一下是否运行丢数据。修改topic数据保存时间为一个小时。一个小时以上的数据会丢失。
/data/kafka/bin/kafka-configs.sh --bootstrap-server 192.168.1.231:9092 --alter --topic my-topic --entity-default-config retention.ms=3600000
```
![](/img/newimg/2024-06-22-05.png)

#### 4、创建需要迁移的topic的move文件
```
root@kafka-2:~# cat topics-to-move.json
{
  "topics": [
    {
      "topic": "my-topic"
    }
  ]
} 
```
#### 5、通过命令生成迁移文件，包含需要迁移到哪几个broker。
```
# 前面这个命令会生成两个部分，分别问现状和迁移计划。 grep Proposed -A1 | grep -v Proposed 过滤掉Current部分，只保留迁移计划。
/data/kafka/bin/kafka-reassign-partitions.sh --bootstrap-server 192.168.1.231:9092 --topics-to-move-json-file topics-to-move.json --broker-list "4,5,6" --generate  | grep Proposed -A1 | grep -v Proposed  > move.json
```
![](/img/newimg/2024-06-22-06.png)

#### 6、执行分区重新分配
```
root@kafka-2:~# /data/kafka/bin/kafka-reassign-partitions.sh --bootstrap-server 192.168.1.231:9092 --reassignment-json-file move.json --execute
Current partition replica assignment

{"version":1,"partitions":[{"topic":"my-topic","partition":0,"replicas":[0,1,2],"log_dirs":["any","any","any"]},{"topic":"my-topic","partition":1,"replicas":[1,2,0],"log_dirs":["any","any","any"]},{"topic":"my-topic","partition":2,"replicas":[2,1,0],"log_dirs":["any","any","any"]}]}

Save this to use as the --reassignment-json-file option during rollback
Successfully started partition reassignments for my-topic-0,my-topic-1,my-topic-2
```
![](/img/newimg/2024-06-22-07.png)
#### 7、验证重新分配状态
```
root@kafka-2:~# /data/kafka/bin/kafka-reassign-partitions.sh --bootstrap-server 192.168.1.231:9092 --reassignment-json-file mytopic-reassignment-plan.json --verify
Status of partition reassignment:
There is no active reassignment of partition my-topic-0, but replica set is 5,4,6 rather than 0,1,2.
There is no active reassignment of partition my-topic-1, but replica set is 6,5,4 rather than 1,2,0.
There is no active reassignment of partition my-topic-2, but replica set is 4,6,5 rather than 2,1,0.

Clearing broker-level throttles on brokers 0,5,1,6,2,3,4
Clearing topic-level throttles on topic my-topic
```
![](/img/newimg/2024-06-22-08.png)
#### 8、查看 topic 详情
```
root@kafka-2:~# /data/kafka/bin/kafka-topics.sh --describe --topic my-topic --bootstrap-server 192.168.1.231:9092
Topic: my-topic	TopicId: 1FtXs5m8TMyjC18Qjs3ttg	PartitionCount: 3	ReplicationFactor: 3	Configs: segment.bytes=1073741824
	Topic: my-topic	Partition: 0	Leader: 5	Replicas: 5,4,6	Isr: 5,6,4
	Topic: my-topic	Partition: 1	Leader: 6	Replicas: 6,5,4	Isr: 5,6,4
	Topic: my-topic	Partition: 2	Leader: 4	Replicas: 4,6,5	Isr: 5,6,4
```
![](/img/newimg/2024-06-22-09.png)
#### 9、操作恢复topic数据保存时间，(如果前面操作了的话)
```
root@kafka-2:~# /data/kafka/bin/kafka-configs.sh --bootstrap-server 192.168.1.231:9092 --alter --topic my-topic --entity-default-config retention.ms=360000000
entity-default-config is not a recognized option
```
完成。