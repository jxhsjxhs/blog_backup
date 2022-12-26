---
title: kafka常用管理命令和脚本
date: 2022-12-14 11:25:23
index_img: https://tva1.sinaimg.cn/large/008vxvgGgy1h936eu9i0yj30uo0gyq3r.jpg
banner_img: https://tva1.sinaimg.cn/large/008vxvgGgy1h936eu9i0yj30uo0gyq3r.jpg
tags:
---


### 系统
#### 启动 Kafka
`-daemon` 参数可以让 Kafka 在后台运行。
> kafka-server-start.sh -daemon /usr/local/kafka/config/server.properties

#### 指定 JMX 端口启动
JMX 的全称为 Java Management Extensions。顾名思义，是管理 Java 的一种扩展，通过 JMX 可以方便我们监控 Kafka 的内存，线程，CPU 的使用情况，以及生产和消费消息的指标。
> JMX_PORT=9999 kafka-server-start.sh -daemon /usr/local/kafka/config/server.properties

#### 停止 Kafka
> kafka-server-stop.sh 

### Topic
#### 创建Topic

> kafka-topics.sh --create  --bootstrap-server <zk-service>:9092 --replication-factor 3 --partitions 3 --topic <topic-name>

#### 列出所有 Topic
> kafka-topics.sh  --bootstrap-server <zk-service>:9092 --list

#### 查看指定 Topic
> kafka-topics.sh --bootstrap-server <zk-service>:9092 --describe --topic <topic-name>

#### 删除指定 Topic
> kafka-topics.sh --bootstrap-server  <zk-service>:9092 --delete --topic <topic-name>

#### 扩展 Topic 的 Partition 数量
artition 数量只能扩大不能缩小。
> kafka-topics.sh --bootstrap-server <zk-service>:9092 --topic app --alter --partitions 30

#### 扩展 topic 每个 partition 的副本数量
replication factor 可以扩大也可以缩小，最多不能超过 broker 数量。先创建一个文件名为 increace-factor.json，这里要扩展的是 mysql-audit-log 这个 topic 的 partition 到 15 个：0，1，2 为 broker id。
```
{"version":1,
"partitions":[
{"topic":"mysql-audit-log","partition":0,"replicas":[0,1,2]},
{"topic":"mysql-audit-log","partition":1,"replicas":[0,1,2]},
{"topic":"mysql-audit-log","partition":2,"replicas":[0,1,2]},
{"topic":"mysql-audit-log","partition":3,"replicas":[0,1,2]},
{"topic":"mysql-audit-log","partition":4,"replicas":[0,1,2]},
{"topic":"mysql-audit-log","partition":5,"replicas":[0,1,2]},
{"topic":"mysql-audit-log","partition":6,"replicas":[0,1,2]},
{"topic":"mysql-audit-log","partition":7,"replicas":[0,1,2]},
{"topic":"mysql-audit-log","partition":8,"replicas":[0,1,2]},
{"topic":"mysql-audit-log","partition":9,"replicas":[0,1,2]},
{"topic":"mysql-audit-log","partition":10,"replicas":[0,1,2]},
{"topic":"mysql-audit-log","partition":11,"replicas":[0,1,2]},
{"topic":"mysql-audit-log","partition":12,"replicas":[0,1,2]},
{"topic":"mysql-audit-log","partition":13,"replicas":[0,1,2]},
{"topic":"mysql-audit-log","partition":14,"replicas":[0,1,2]}
]}
```
> kafka-reassign-partitions.sh --zookeeper <zk-service>:2181 --reassignment-json-file  increace-factor.json --execute 

#### 查看 Topic 数据大小
```
#方法一
kafka-log-dirs.sh \
  --bootstrap-server 192.168.1.87:9092 \
  --topic-list mytopic \
  --describe \
  | grep -oP '(?<=size":)\d+'  \
  | awk '{ sum += $1 } END { print sum }'
  
#返回结果，单位 Byte
648

#方法二，需要安装 jq
kafka-log-dirs.sh \
    --bootstrap-server 192.168.1.87:9092 \
    --topic-list mytopic \
    --describe \
  | grep '^{' \
  | jq '[ ..|.size? | numbers ] | add'

#返回结果，单位 Byte
648
```
### 消费者组 Consumer Group

#### 列出所有的 Consumer Group

>  kafka-consumer-groups.sh --bootstrap-server <zk-service>:9092 --list

#### 查看指定 Consumer Group 详情
```
GROUP:消费者 group
TOPIC:话题 id
PARTITION:分区 id
CURRENT-OFFSET:当前已消费的条数
LOG-END-OFFSET:总条数
LAG:未消费的条数
CONSUMER-ID:消费者 id
HOST:消费者 ip 地址
CLIENT-ID:客户端 id
```

```
#这里查看的是 logstash_mysql 这个消费者 group 的消费情况
kafka-consumer-groups.sh --bootstrap-server 10.37.62.20:9092 --describe --group logstash_mysql

#返回结果
GROUP           TOPIC           PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG             CONSUMER-ID                                      HOST            CLIENT-ID
logstash_mysql  mysql-audit-log 11         1312115         1312857         742             logstash-5-0545a8a7-f7bd-430c-b619-7a2b206addd2  /10.37.62.24    logstash-5
logstash_mysql  mysql-audit-log 1          1312593         1313345         752             logstash-0-d86bd51a-d010-45de-aa6f-f6da8542b779  /10.37.62.23    logstash-0
logstash_mysql  mysql-audit-log 2          1309548         1310317         769             logstash-1-496340ea-935d-444d-a184-51d42e225054  /10.37.62.24    logstash-1
logstash_mysql  mysql-audit-log 12         1313083         1313194         111             logstash-6-806b20cb-a9af-49c1-b37d-ccb33a646ab2  /10.37.62.24    logstash-6
logstash_mysql  mysql-audit-log 6          1310984         1311192         208             logstash-13-8d474bf6-e8d0-4b8a-b319-cf5e2e6cc078 /10.37.62.24    logstash-13
logstash_mysql  mysql-audit-log 9          1312998         1313768         770             logstash-3-29863fb0-6708-4fb1-9e28-bd81c30ce8ef  /10.37.62.24    logstash-3
logstash_mysql  mysql-audit-log 4          1315150         1315276         126             logstash-11-6d66a188-85b7-476b-bd89-5423ef48cd01 /10.37.62.24    logstash-11
logstash_mysql  mysql-audit-log 0          22770935522     22770935650     128             logstash-0-7be475d6-a49e-4ff9-bf83-6b83f6067306  /10.37.62.24    logstash-0
logstash_mysql  mysql-audit-log 8          1309956         1310103         147             logstash-2-3c313c6f-8c98-4333-8bad-2f9696457d7d  /10.37.62.24    logstash-2
logstash_mysql  mysql-audit-log 13         1314659         1314775         116             logstash-7-e98fd14e-e7f6-45e5-8ccf-2442058f0bc9  /10.37.62.24    logstash-7
logstash_mysql  mysql-audit-log 14         1313145         1313250         105             logstash-8-2c3345a8-f8f1-4f08-a18e-333dff2f0d65  /10.37.62.24    logstash-8
logstash_mysql  mysql-audit-log 5          1314037         1314297         260             logstash-12-ce018227-9e59-4137-a23f-5ccc0c7d4f6a /10.37.62.24    logstash-12
logstash_mysql  mysql-audit-log 10         1312883         1312962         79              logstash-4-9eb84ae4-3351-4083-9b1f-288910a6c3b8  /10.37.62.24    logstash-4
logstash_mysql  mysql-audit-log 7          1312476         1313200         724             logstash-14-680c982e-5cf3-406b-810a-4d5c96b5bdee /10.37.62.24    logstash-14
logstash_mysql  mysql-audit-log 3          1313227         1313328         101    
```
#### 删除指定 Consumer Group
> kafka-topics.sh --bootstrap-server <zk-service>:9092 --delete --topic pgw-nginx

### 消息
#### 生产消息
```
kafka-console-producer.sh --broker-list 11.8.36.125:9092 --topic mytopic
>this is my topic
```

#### 生产消息指定 Key
`key.separator=`, 指定以逗号作为 key 和 value 的分隔符。
```
kafka-console-producer.sh --broker-list kafka1:9092 --topic cr7-topic --property parse.key=true --property key.separator=,

>mykey,{"orderAmount":1000,"orderId":1,"productId":101,"productNum":1}
```
#### 消费消息
##### 从头开始消费
从头开始消费是可以消费到之前的消息的，通过 `--from-beginning` 指定：

```
kafka-console-consumer.sh --bootstrap-server 11.8.36.125:9092 --topic mytopic --from-beginning
this is my topic
```
##### 从尾部开始消费
`--offset latest` 指定从尾部开始消费，另外还需要指定 partition，可以指定多个：
```
kafka-console-consumer.sh --bootstrap-server 11.8.36.125:9092 --topic mytopic  --offset latest  --partition 0 1 2 
```
##### 消费指定条数的消息

`--max-messages` 指定取的个数：

```
kafka-console-consumer.sh --bootstrap-server 11.8.36.125:9092 --topic mytopic  --offset latest  --partition 0 1 2 --max-messages 2
bobo
1111
Processed a total of 2 messages
```

##### 指定消费组进行消费
`--consumer-property group.id=<消费者组名>`执行消费者组进行消费：
> kafka-console-consumer.sh --bootstrap-server  kafka1:9092 --topic test_partition --consumer-property  group.id=test_group --from-beginning 
##### 查看消息具体内容

```
kafka-dump-log.sh --files cr7-topic-0/00000000000000000000.log  -deep-iteration --print-data-log
 
 #输出结果
| offset: 1080 CreateTime: 1615020877664 keysize: 1 valuesize: 63 sequence: -1 headerKeys: [] key: 1 payload: {"orderAmount":1000,"orderId":1,"productId":101,"productNum":1}
| offset: 1081 CreateTime: 1615020877677 keysize: 1 valuesize: 63 sequence: -1 headerKeys: [] key: 5 payload: {"orderAmount":1000,"orderId":5,"productId":105,"productNum":5}
| offset: 1082 CreateTime: 1615020877677 keysize: 1 valuesize: 63 sequence: -1 headerKeys: [] key: 7 payload: {"orderAmount":1000,"orderId":7,"productId":107,"productNum":7}
| offset: 1083 CreateTime: 1615020877677 keysize: 1 valuesize: 63 sequence: -1 headerKeys: [] key: 8 payload: {"orderAmount":1000,"orderId":8,"productId":108,"productNum":8}
| offset: 1084 CreateTime: 1615020877677 keysize: 2 valuesize: 65 sequence: -1 headerKeys: [] key: 11 payload: {"orderAmount":1000,"orderId":11,"productId":111,"productNum":11}
| offset: 1085 CreateTime: 1615020877677 keysize: 2 valuesize: 65 sequence: -1 headerKeys: [] key: 15 payload: {"orderAmount":1000,"orderId":15,"productId":115,"productNum":15}
| offset: 1086 CreateTime: 1615020877678 keysize: 2 valuesize: 65 sequence: -1 headerKeys: [] key: 17 payload: {"orderAmount":1000,"orderId":17,"productId":117,"productNum":17}
| offset: 1087 CreateTime: 1615020877678 keysize: 2 valuesize: 65 sequence: -1 headerKeys: [] key: 21 payload: {"orderAmount":1000,"orderId":21,"productId":121,"productNum":21}
```

##### 查看 Topic 中当前消息总数

Kafka 自带的命令没有直接提供这样的功能，要使用 Kafka 提供的工具类 GetOffsetShell 来计算给定 Topic 每个分区当前最早位移和最新位移，差值就是每个分区的当前的消息总数，将该 Topic 所有分区的消息总数累加就能得到该 Topic 总的消息数。

首先查询 Topic 中每个分区 offset 的最小值（起始位置），使用 `--time -2 `参数。一个分区的起始位置并不是每时每刻都为 0 ，因为日志清理的动作会清理旧的数据，所以分区的起始位置会自然而然地增加。
```
kafka-run-class.sh kafka.tools.GetOffsetShell --broker-list kafka1:9092 -topic test-topic  --time -2

#前面是分区号，后面是 offset
test-topic:0:0
test-topic:1:0
```
然后使用`--time -1 `参数查询 Topic 各个分区的 offset 的最大值。
```
kafka-run-class.sh kafka.tools.GetOffsetShell --broker-list kafka1:9092 --time -1 --topic test-topic

#输出结果
test-topic:0:5500000
test-topic:1:5500000
```
对于本例来说，test-topic 中当前总的消息数为 (5500000 - 0) + （5500000 - 0），等于 1100 万条。如果只是要获取 Topic 中总的消息数（包括已经从 Kafka 删除的消息），那么只需要将 Topic 中每个 Partition 的 Offset 累加即可。


### Offset
#### 重置消费者 Offset

```
#查看消费者组消费情况
#目前的 0 分区 CURRENT-OFFSET 是 4，2 分区 CURRENT-OFFSET 是 6
kafka-consumer-groups.sh --bootstrap-server kafka1:9092 --describe --group my-consumer-group

#返回结果
Consumer group 'my-consumer-group' has no active members.

GROUP             TOPIC                 PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG             CONSUMER-ID     HOST            CLIENT-ID
my-consumer-group transaction-topic-msg 2          6               6               0               -               -               -
my-consumer-group transaction-topic-msg 1          0               0               0               -               -               -
my-consumer-group transaction-topic-msg 0          4               4               0               -               -               -         -

#重置消费者组 offset 为 3，重置是所有分区一起重置
kafka-consumer-groups.sh --bootstrap-server kafka1:9092 --group my-consumer-group --reset-offsets --execute --to-offset 3 --topic transaction-topic-msg

#返回结果
[2021-06-25 10:44:51,848] WARN New offset (3) is higher than latest offset for topic partition transaction-topic-msg-1. Value will be set to 0 (kafka.admin.ConsumerGroupCommand$)

GROUP                          TOPIC                          PARTITION  NEW-OFFSET     
my-consumer-group              transaction-topic-msg          0          3              
my-consumer-group              transaction-topic-msg          1          0              
my-consumer-group              transaction-topic-msg          2          3              

#可以看到 0 分区和 2 分区的 CURRENT-OFFSET 都变为 3 了
kafka-consumer-groups.sh --bootstrap-server kafka1:9092 --describe --group my-consumer-group

#返回结果
Consumer group 'my-consumer-group' has no active members.

GROUP             TOPIC                 PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG             CONSUMER-ID     HOST            CLIENT-ID
my-consumer-group transaction-topic-msg 2          3               6               3               -               -               -
my-consumer-group transaction-topic-msg 1          0               0               0               -               -               -
my-consumer-group transaction-topic-msg 0          3               4               1               -               -               -

#可以重新消费到之前的数据
kafka-console-consumer.sh --bootstrap-server kafka1:9092 --topic transaction-topic-msg  --group my-consumer-group 

#返回结果
message-111111
message-333333
```

### 性能测试
```
--num-records 10000000: 向指定主题发送了 1 千万条消息。
--record-size 1024: 每条消息的大小为 1024KB。
--throughput -1: 不限制吞吐量。
--producer-props: 指定生产者参数。
    acks=-1: 这要求 ISR 列表里跟 leader 保持同步的那些 follower 都要把消息同步过去，才能认为这条消息是写入成功。
    linger.ms=2000: batch.size 和 linger.ms 是对 kafka producer 性能影响比较大的两个参数。batch.size 是 producer 批量发送的基本单位，默认是 16384Bytes，即 16kB；lingger.ms 是 sender 线程在检查 batch 是否 ready 时候，判断有没有过期的参数，默认大小是 0ms。
    compression.type=lz4: 使用 lz4 压缩算法。
```
```
[root@kafka1 ~]# kafka-producer-perf-test.sh --topic test_producer_perf --num-records 10000000 --throughput -1 --record-size 1024 --producer-props bootstrap.servers=kafka1:9092 acks=-1 linger.ms=2000 compression.type=lz4

#输出结果
705600 records sent, 141063.6 records/sec (137.76 MB/sec), 54.8 ms avg latency, 557.0 ms max latency.
1204178 records sent, 240739.3 records/sec (235.10 MB/sec), 44.1 ms avg latency, 402.0 ms max latency.
1370938 records sent, 274187.6 records/sec (267.76 MB/sec), 27.9 ms avg latency, 311.0 ms max latency.
1464605 records sent, 292628.4 records/sec (285.77 MB/sec), 19.2 ms avg latency, 139.0 ms max latency.
1477239 records sent, 295447.8 records/sec (288.52 MB/sec), 31.8 ms avg latency, 290.0 ms max latency.
1446682 records sent, 289336.4 records/sec (282.56 MB/sec), 26.4 ms avg latency, 281.0 ms max latency.
1555098 records sent, 311019.6 records/sec (303.73 MB/sec), 37.6 ms avg latency, 344.0 ms max latency.
10000000 records sent, 263894.020162 records/sec (257.71 MB/sec), 32.60 ms avg latency, 557.00 ms max latency, 12 ms 50th, 140 ms 95th, 262 ms 99th, 396 ms 99.9th.
```
我们应该关心延时的概率分布情况，仅仅知道一个平均值是没有意义的。这就是这里计算分位数的原因。通常我们关注到 99th 分位就可以了。比如在上面的输出中，99th 值是 262 ms，这表明测试生产者生产的消息中，有 99% 消息的延时都在 262 ms 以内。你完全可以把这个数据当作这个生产者对外承诺的 SLA。

##### 消费者性能测试
```
[root@kafka1 ~]# kafka-consumer-perf-test.sh --broker-list kafka1:9092 --messages 10000000 --topic test_producer_perf

#输出结果
start.time, end.time, data.consumed.in.MB, MB.sec, data.consumed.in.nMsg, nMsg.sec, rebalance.time.ms, fetch.time.ms, fetch.MB.sec, fetch.nMsg.sec
2021-03-09 10:34:18:447, 2021-03-09 10:34:33:948, 9765.6250, 629.9997, 10000000, 645119.6697, 1615257259068, -1615257243567, -0.0000, -0.0062
```

虽然输出格式有所差别，但该脚本也会打印出消费者的吞吐量数据。比如本例中的 629.9997MB/s。有点令人遗憾的是，它没有计算不同分位数下的分布情况。因此，在实际使用过程中，这个脚本的使用率要比生产者性能测试脚本的使用率低。


### 修改动态参数

##### 修改 Broker 动态参数
```
修改动态参数无需重启 Broker，动态 Broker 参数的使用场景非常广泛，通常包括但不限于以下几种：

动态调整 Broker 端各种线程池大小，实时应对突发流量。
动态调整 Broker 端连接信息或安全配置信息。
动态更新 SSL Keystore 有效期。
动态调整 Broker 端 Compact 操作性能。
实时变更 JMX 指标收集器 (JMX Metrics Reporter)。
Kafka Broker Config 的参数有以下 3 种类型：

read-only：被标记为 read-only 的参数和原来的参数行为一样，只有重启 Broker，才能令修改生效。
per-broker：被标记为 per-broker 的参数属于动态参数，修改它之后，只会在对应的 Broker 上生效。
cluster-wide：被标记为 cluster-wide 的参数也属于动态参数，修改它之后，会在整个集群范围内生效，也就是说，对所有 Broker 都生效。你也可以为具体的 Broker 修改 cluster-wide 参数。
在集群层面设置全局值，即设置 cluster-wide 范围值，将 unclean.leader.election.enable 参数在集群层面设置为 true。
```

释案
```
kafka-configs.sh --bootstrap-server  10.37.249.58:9092 \
--entity-type brokers --entity-default --alter \
--add-config unclean.leader.election.enable=true

#返回结果
Completed updating default config for brokers in the cluster.
```

如果要设置 cluster-wide 范围的动态参数，需要显式指定 entity-default。现在，我们使用下面的命令来查看一下刚才的配置是否成功。

```
kafka-configs.sh --bootstrap-server 10.37.249.58:9092 \
--entity-type brokers --entity-default --describe

#返回结果
Default configs for brokers in the cluster are:
  unclean.leader.election.enable=true sensitive=false synonyms={DYNAMIC_DEFAULT_BROKER_CONFIG:unclean.leader.election.enable=true}
```
在 Zookeeper 上查看 /config/brokers/ 节点可以查看 cluster-wide 的动态参数设置。
```
[zk: (CONNECTED) ] > get /config/brokers/1
{"version":1,"config":{"unclean.leader.election.enable":"false"}}
cZxid = 17179869574
ctime = 1631246495120
mZxid = 17179869574
mtime = 1631246495120
pZxid = 17179869574
cversion = 0
dataVersion = 0
aclVersion = 0
ephemeralOwner = 0
dataLength = 65
numChildren = 0[zk: (CONNECTED) ] > get /config/brokers/<default>[zk: (CONNECTED) ] > get /config/brokers/1
```
删除 cluster-wide 范围动态参数。

```
kafka-configs.sh --bootstrap-server 10.37.249.58:9092 \
--entity-type brokers --entity-default --alter \
--delete-config unclean.leader.election.enable

#返回结果
Completed updating default config for brokers in the cluster.
```

删除 per-broker 范围参数。
```
kafka-configs.sh --bootstrap-server 10.37.249.58:9092 \
--entity-type brokers --entity-name 1 --alter \
--delete-config unclean.leader.election.enable

#返回结果
Completed updating config for broker 1.
```

修改 Topic 动态参数
设置 Topic test-topic 的 `retention.ms` 为 10000。
```
kafka-configs.sh --bootstrap-server  10.37.249.58:9092 \
--entity-type topics --entity-name test-topic --alter \
--add-config retention.ms=10000
```
查看设置的 Topic 动态参数。

```
kafka-configs.sh --bootstrap-server  10.37.249.58:9092 \
--entity-type topics --entity-name test-topic --describe

#返回结果
Dynamic configs for topic test-topic are:
  retention.ms=10000 sensitive=false synonyms={DYNAMIC_TOPIC_CONFIG:retention.ms=10000}
```

在 Zookeeper 上可以查看 /config/topics/ 来查看 Topic 动态参数。
```
[zk: (CONNECTED) ] > get /config/topics/test-topic
{"version":1,"config":{"retention.ms":"10000"}}
cZxid = 17179869460
ctime = 1631245744105
mZxid = 17179869619
mtime = 1631250116481
pZxid = 17179869460
cversion = 0
dataVersion = 10
aclVersion = 0
ephemeralOwner = 0
dataLength = 47
numChildren = 0[zk: (CONNECTED) ] > get /config/topics/test-topic
```
删除 Topic 动态参数。
```
kafka-configs.sh --bootstrap-server  10.37.249.58:9092 \
--entity-type topics --entity-name test-topic --alter \
--delete-config retention.ms
```
### Kafka 集群一键启动/停止脚本
#### 环境变量设置：
```
#/etc/profile 文件
export KAFKA_HOME=/usr/local/kafka
export PATH=$PATH:$KAFKA_HOME/bin
```
一键启动/停止脚本，查看状态需要安装 jps 工具。

```
#! /bin/bash
# 填写 Kafka Broker 节点地址
hosts=(kafka1 kafka2 kafka3)

# 打印启动分布式脚本信息
mill=`date "+%N"`
tdate=`date "+%Y-%m-%d %H:%M:%S,${mill:0:3}"`

echo [$tdate] INFO [Kafka Cluster] begins to execute the $1 operation.

# 执行分布式开启命令
function start()
{
        for i in ${hosts[@]}
                do
                        smill=`date "+%N"`
                        stdate=`date "+%Y-%m-%d %H:%M:%S,${smill:0:3}"`
                        ssh root@$i "source /etc/profile;echo [$stdate] INFO [Kafka Broker $i] begins to execute the startup operation.;kafka-server-start.sh $KAFKA_HOME/config/server.properties>/dev/null" &
                        sleep 1
                done
}

# 执行分布式关闭命令
function stop()
{
        for i in ${hosts[@]}
                do
                        smill=`date "+%N"`
                        stdate=`date "+%Y-%m-%d %H:%M:%S,${smill:0:3}"`
                        ssh root@$i "source /etc/profile;echo [$stdate] INFO [Kafka Broker $i] begins to execute the shutdown operation.;kafka-server-stop.sh>/dev/null;" &
                        sleep 1
                done
}

# 查看 Kafka Broker 节点状态
function status()
{
        for i in ${hosts[@]}
                do
                        smill=`date "+%N"`
                        stdate=`date "+%Y-%m-%d %H:%M:%S,${smill:0:3}"`
                        ssh root@$i "source /etc/profile;echo [$stdate] INFO [Kafka Broker $i] status message is :;jps | grep Kafka;" &
                        sleep 1
                done
}

# 判断输入的 Kafka 命令参数是否有效
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        RETVAL=1
esac
```

