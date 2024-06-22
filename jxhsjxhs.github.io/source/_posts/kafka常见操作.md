---
title: kafka常见操作
date: 2024-06-22 17:12:36
tags:
---



日常操作命令
查看topic 
bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --list | grep test
查看某个topic详情
bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --describe --topic test

bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --list | grep flink_risk_deposit_address_info
bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --create --partitions 12 --replication-factor 3 --topic flink_risk_deposit_address_info
bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --describe --topic flink_risk_deposit_address_info
bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --create --topic test --partitions 3 --replication-factor 3 --config segment.bytes=1073741824 --config max.message.bytes=2097152 --config retention.bytes=1073741824

删除消费组–delete
删除指定消费组--group，删除前后必须先查询消费组是否存在，再进行删除操作
bin/kafka-consumer-groups.sh --bootstrap-server 127.0.0.1:9092 --list | grep console-consumer-37605
bin/kafka-consumer-groups.sh --delete --bootstrap-server 127.0.0.1:9092 --group console-consumer-37605

bin/kafka-console-consumer.sh --bootstrap-server 127.0.0.1:9092 --group test_group_v1 --topic spot_match
bin/kafka-consumer-groups.sh --bootstrap-server 127.0.0.1:9092 --list | grep test_group_v1
bin/kafka-consumer-groups.sh --bootstrap-server 127.0.0.1:9092 --delete --group test_group_v1

查看kafka集群监控情况
./bin/zookeeper-shell.sh localhost:2181
ls /kafka/brokers/ids


查看kafka集群监控qing
./bin/zookeeper-shell.sh localhost:2181
ls /kafka/brokers/ids

查看kafka版本
cd /data/app/kafka_cluster
find ./libs/ -name \*kafka_\* | head -1 | grep -o '\kafka[^\n]*'
kafka_2.11-2.4.0-test-sources.jar
kafka_2.12-3.1.0.jar

一、Kafka常用命令
1.1 topic相关

## 查看所有topic
bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --list 
bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --list --exclude-internal
bin/kafka-topics.sh --bootstrap-server `ip a|grep 10.10 |awk -F ' |/' '{print $6}'`:9092 --list

## 查看所有topic详情（副本、分区、ISR等）
bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --describe
bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --describe --exclude-internal

## 查看某个topic详情
bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --describe --topic test
### 合约集群端口特殊
bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9072 --describe --topic test


## 创建topic,3副本 3分区
bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --create --topic test --replication-factor 3 --partitions 3
bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --create --topic test --replication-factor 3 --partitions 1 
bin/kafka-topics.sh --bootstrap-server localhost:9092 --create --topic test --partitions 3 --replication-factor 3 --config segment.bytes=1073741824 --config max.message.bytes=2097152 --config retention.bytes=1073741824
bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --create --topic transfer_events --replication-factor 3 --partitions 6 --config retention.bytes=10737418240 --config retention.ms=86400000

bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --create --topic test --replication-factor 3 --partitions 128 --config segment.bytes=1073741824 --config retention.ms=172800000 --config max.message.bytes=52428800 --config retention.bytes=10737418240  

bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --create --topic test --replication-factor 3 --partitions 5 --config segment.bytes=1073741824 --config retention.ms=259200000 --config max.message.bytes=2097152 --config retention.bytes=10737418240 --config min.insync.replicas=2  


##修改topic配置
bin/kafka-configs.sh  --zookeeper localhost:2181 --entity-type topics --entity-name push_spot --alter --add-config retention.bytes=1073741824


## 调整分区数量
扩大分区后，不可再次调整缩减
bin/kafka-topics.sh --alter --bootstrap-server 127.0.0.1:9092 --topic test --partitions 3


【慎重操作】
## 删除topic，需要将参数设置为delete.topic.enable=true，如果还是删不了则删除kafka中的所有分区log，及通过zk客户端删除
bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --list  | grep list
bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --delete --topic test

## 查看topic各个分区的消息数量
bin/kafka-run-class.sh  kafka.tools.GetOffsetShell --broker-list 127.0.0.1:9092 --time -1  --topic test

# 动态调整topic配置


bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --describe --topic test
bin/kafka-topics.sh --zookeeper 127.0.0.1:2181 --alter --config min.insync.replicas=2 --topic test


## 调整设置过期时间，注意zk的kafka路径
### 查看当前topic额外配置
bin/kafka-configs.sh --zookeeper 127.0.0.1:2181 --entity-type topics --entity-name test --describe
bin/kafka-configs.sh --zookeeper 127.0.0.1:2181/kafka --entity-type topics --entity-name test --describe

### 调整topic过期时间
bin/kafka-configs.sh --zookeeper 127.0.0.1:2181 --entity-type topics --entity-name test --alter --add-config retention.ms=86400000
bin/kafka-configs.sh --zookeeper 127.0.0.1:2181/kafka --entity-type topics --entity-name test --alter --add-config retention.ms=86400000
bin/kafka-configs.sh --zookeeper 127.0.0.1:2181/kafka --entity-type topics --entity-name test-delete --alter --add-config retention.ms=1800000,retention.bytes=209715200

bin/kafka-configs.sh  --zookeeper 127.0.0.1:2181 --entity-type topics --entity-name test --alter --add-config retention.ms=86400000

### 动态添加配置删除配置
bin/kafka-topics.sh --zookeeper 127.0.0.1:2181 --alter --config retention.ms=172800000 --topic mxc_spot_match_result_usdt
bin/kafka-topics.sh --zookeeper 127.0.0.1:2181 --alter --delete-config retention.ms --topic mxc_spot_match_result_usdt

### 确认topic修改配置生效
./bin/kafka-configs.sh --zookeeper 127.0.0.1:2181 --entity-type topics --entity-name test --describe
./bin/kafka-configs.sh --zookeeper 127.0.0.1:2181/kafka --entity-type topics --entity-name test --describe

1.2 模拟kafka生产消费
## 生产
bin/kafka-console-producer.sh --broker-list 127.0.0.1:9092 --topic test

## 消费，--from-beginning参数表示从头开始
bin/kafka-console-consumer.sh --bootstrap-server 127.0.0.1:9092 --topic test
bin/kafka-console-consumer.sh --bootstrap-server 127.0.0.1:9092 --topic test --from-beginning
此处需要注意，生产者和测试者指定的broker必须和配置文件中zookeeper.connect和listeners中的地址一至，如写127.0.0.1生产者会类似如下信息：
WARN [Producer clientId=console-producer] Connection to node -1 could not be established. Broker may not be available. (org.apache.kafka.clients.NetworkClient)
消费者会报错类似错误：
WARN [Consumer clientId=consumer-1, groupId=console-consumer-8350] Connection to node -1 could not be established. Broker may not be available. (org.apache.kafka.clients.NetworkClient)
1.3 消费者相关
## 显示消费者列表
bin/kafka-consumer-groups.sh --bootstrap-server 127.0.0.1:9092 --list
bin/kafka-consumer-groups.sh --bootstrap-server 127.0.0.1:9092 --list | grep test-consumer
 
## 查看所有消费组详情--all-groups
bin/kafka-consumer-groups.sh --bootstrap-server 127.0.0.1:9092 --describe --all-groups

## 获取某消费者消费某个topic的offset,--group
bin/kafka-consumer-groups.sh --bootstrap-server 127.0.0.1:9092 --describe --group test-consumer
bin/kafka-consumer-groups.sh --bootstrap-server 127.0.0.1:9092 --describe --group console-consumer-37605
bin/kafka-consumer-groups.sh --bootstrap-server 127.0.0.1:9092 --describe --group console-consumer-37605

## 查询消费者成员信息--members
所有消费组成员信息
bin/kafka-consumer-groups.sh --describe --all-groups --members --bootstrap-server 127.0.0.1:9092

指定消费组成员信息
bin/kafka-consumer-groups.sh --describe --members --group console-consumer-37605 --bootstrap-server 127.0.0.1:9092
GROUP                  CONSUMER-ID                                           HOST            CLIENT-ID        #PARTITIONS     
console-consumer-37605 console-consumer-9a4ad46f-8c66-40ed-b1a1-d1436ec52fd9 /172.18.0.1     console-consumer 1

## 查询消费者状态信息--state
所有消费组状态信息
bin/kafka-consumer-groups.sh --describe --all-groups --state --bootstrap-server 127.0.0.1:9092
指定消费组状态信息
bin/kafka-consumer-groups.sh --describe --state --group console-consumer-37605 --bootstrap-server 127.0.0.1:9092



##查询消费者有多少数据没有被消费
./kafka-consumer-groups.sh  --bootstrap-server 10.10.10.158:9092 --describe  --group=planorder01

 

【危险操作】
## 删除消费者组--delete
DeleteGroupsRequest

删除消费组–delete
删除指定消费组--group，删除前后必须先查询消费组是否存在，再进行删除操作
bin/kafka-consumer-groups.sh --bootstrap-server 127.0.0.1:9092 --list | grep console-consumer-37605 
bin/kafka-consumer-groups.sh --delete --bootstrap-server 127.0.0.1:9092 --group console-consumer-37605 


【危险操作】
删除所有消费组--all-groups，生产环境禁止执行
bin/kafka-consumer-groups.sh --delete --all-groups --bootstrap-server 127.0.0.1:9092

注意: 想要删除消费组前提是这个消费组的所有客户端都停止消费/不在线才能够成功删除;否则会报下面异常
Error: Deletion of some consumer groups failed:
* Group 'console-consumer-37605' could not be deleted due to: java.util.concurrent.ExecutionException: org.apache.kafka.common.errors.GroupNotEmptyException: The group is not empty.



 【危险操作】
## 重置消费组的偏移量 --reset-offsets
# AWS MSK中时间为UTC时间
bin/kafka-consumer-groups.sh --bootstrap-server 127.0.0.1:9092 --group test_group --reset-offsets --to-datetime 2023-09-21T10:35:00.000 --topic canal_spot --execute

调整消费者对某个topic的offset，发生阻塞等情况时可使用
bin/kafka-consumer-groups.sh --bootstrap-server 127.0.0.1:9092 --group groupName --reset-offsets --to-offset 1000 --topic topicName --execute
bin/kafka-consumer-groups.sh --bootstrap-server 127.0.0.1:9092 --group console-consumer-37605 --reset-offsets --to-offset 10 --topic test --execute

重置指定消费组的偏移量 --group
重置指定消费组的所有Topic的偏移量--all-topic
bin/kafka-consumer-groups.sh --reset-offsets --to-earliest --group console-consumer-37605 --bootstrap-server 127.0.0.1:9092 --dry-run --all-topics
重置指定消费组的指定Topic的偏移量--topic
bin/kafka-consumer-groups.sh --reset-offsets --to-earliest --group console-consumer-37605 --bootstrap-server 127.0.0.1:9092 --dry-run --topic test

重置所有消费组的偏移量 --all-group
重置所有消费组的所有Topic的偏移量--all-topic
bin/kafka-consumer-groups.sh --reset-offsets --to-earliest --all-group --bootstrap-server 127.0.0.1:9092 --dry-run --all-topic
重置所有消费组中指定Topic的偏移量--topic
bin/kafka-consumer-groups.sh --reset-offsets --to-earliest --all-group --bootstrap-server 127.0.0.1:9092 --dry-run --topic test2

删除偏移量delete-offsets
能够执行成功的一个前提是 消费组这会是不可用状态;
偏移量被删除了之后,Consumer Group下次启动的时候,会从头消费;
sh bin/kafka-consumer-groups.sh --delete-offsets --group console-consumer-37605 --bootstrap-server 127.0.0.1:9092 --topic test
 

重置消费组时间
bin/kafka-consumer-groups.sh --bootstrap-server 127.0.0.1:9092  --delete --group test_group_v1

bin/kafka-consumer-groups.sh --bootstrap-server 127.0.0.1:9092 --group test_group_v1 --reset-offsets --to-datetime 2024-03-10T13:00:00.000 --topic canal_spot --execute


压测数据
bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --create --topic benchmark-test-2 --replication-factor 3 --partitions 3

bin/kafka-producer-perf-test.sh --topic benchmark-test-2 --num-records 100000 --record-size 1000  --throughput 2000 --producer-props bootstrap.servers=127.0.0.1:9092

bin/kafka-consumer-perf-test.sh --bootstrap-server 127.0.0.1:9092 --topic benchmark-test --fetch-size 1048576 --messages 100000 --threads 1


1.4 调整默认分区副本数
## 配置文件中指定默认分区 副本数
num.partitions=3; 当topic不存在系统自动创建时的分区数
default.replication.factor=3 ;当topic不存在系统自动创建时的副本数
offsets.topic.replication.factor=3 ；表示kafka的内部topic consumer_offsets副本数，默认为1

调整topic分区副本数
目前 test 的topic副本和分区都为1

bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --describe --topic test
Topic:test PartitionCount:1  ReplicationFactor:1 Configs:
  Topic: test  Partition: 0  Leader: 1 Replicas: 1 Isr: 1

将分区数调整为3
## 扩容
bin/kafka-topics.sh --alter --bootstrap-server 127.0.0.1:9092 --topic test --partitions 3
WARNING: If partitions are increased for a topic that has a key, the partition logic or ordering of the messages will be affected
Adding partitions succeeded!

## 检查
bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --describe --topic test
Topic:test PartitionCount:3  ReplicationFactor:1 Configs:
  Topic: test  Partition: 0  Leader: 1 Replicas: 1 Isr: 1
  Topic: test  Partition: 1  Leader: 2 Replicas: 2 Isr: 2
  Topic: test  Partition: 2  Leader: 3 Replicas: 3 Isr: 3

> 注意：分区数只能增加，不能减少


将副本数调整为3，首先准备json文件，格式如下：vim test.json
{
    "version": 1, 
    "partitions": [
        {
            "topic": "test", 
            "partition": 0, 
            "replicas": [
                1, 
                2, 
                3
            ]
        },
        {
            "topic": "test", 
            "partition": 1, 
            "replicas": [
                2, 
                1, 
                3
            ]
        },
        {
            "topic": "test", 
            "partition": 2, 
            "replicas": [
                3, 
                2, 
                1
            ]
        }
    ]
}

执行调整命令
bin/kafka-reassign-partitions.sh --bootstrap-server 127.0.0.1:9092 --reassignment-json-file /tmp/test.json --execute
Current partition replica assignment

{"version":1,"partitions":[{"topic":"test","partition":0,"replicas":[1],"log_dirs":["any"]},{"topic":"test","partition":2,"replicas":[3],"log_dirs":["any"]},{"topic":"test","partition":1,"replicas":[2],"log_dirs":["any"]}]}

Save this to use as the --reassignment-json-file option during rollback
Successfully started reassignment of partitions.
检查调整进度
bin/kafka-reassign-partitions.sh --bootstrap-server 127.0.0.1:9092 --reassignment-json-file /tmp/test.json --verify
Status of partition reassignment:
Reassignment of partition test-0 completed successfully
Reassignment of partition test-1 completed successfully
Reassignment of partition test-2 completed successfully

检查调整后的状态
bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --describe --topic test
Topic:test PartitionCount:3  ReplicationFactor:3 Configs:
  Topic: test  Partition: 0  Leader: 1 Replicas: 1,2,3 Isr: 1,2,3
  Topic: test  Partition: 1  Leader: 2 Replicas: 2,1,3 Isr: 2,1,3
  Topic: test  Partition: 2  Leader: 3 Replicas: 3,2,1 Isr: 3,2,1


1.5 kafka集群状态检测
1.5.1 检查集群内kafka服务及集群是否正常。（3分钟）

# 检查是否正常启动，这里以127.0.0.1 IP为例，实际情况，需要修改为实际broker节点IP地址。
1 在Kafka集群其他正常节点执行端口检测命令如下命令，如果端口不通，则节点尚未恢复。
nc -v 127.0.0.1 9092
nc -v 127.0.0.1 2181
 
2 执行jps -l如果看到返回[PID] kafka.Kafka和[PID] org.apache.zookeeper.server.quorum.QuorumPeerMain，说明集群进程正常
3 执行如下命令，查看到kafka启动日志如下，说明节点启动正常。
journalctl -u kafka -f
或
cd /data/app/kafka_cluster
tail -f logs/server.log
INFO [KafkaServer id=[xx]] started (kafka.server.KafkaServer)
 
4 查看kafka集群有[1, 2, 3]三个注册节点存活。
bin/zookeeper-shell.sh localhost:2181
ls /brokers/ids
[1, 2, 3]
查看kafka broker节点日志无报错。
tail -f logs/server.log
确认当前kafka集群状态健康正常，即可进行下一步操作。