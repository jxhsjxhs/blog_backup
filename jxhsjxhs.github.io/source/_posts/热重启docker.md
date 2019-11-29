---
title: 热重启docker
date: 2019-11-29 11:13:32
tags:
---

## 背景
众所周知，由于docker架构原因,docker是有守护进程的。而所有的容器进程父进程都是这个守护进程,如下图:
![docker架构](https://i.loli.net/2019/11/29/JrG9j7QxCK1HpAL.png)

这样的蠢架构导致了很多问题:
- 生产环境docker内存泄漏无法处理或者处理繁琐
- 升级生产docker版本繁琐



从docker 1.12以后更新了热更新的配置,虽然架构还是不咋地,但是至少解决了以上问题

## 热更新配置
### Step 1. 使用 docker live restore && SIGHU reload 配置
```
配置 live restore 到 /etc/docker/daemon.json （注意加逗号）
{ "live-restore": true }
reload  docker 配置【⚠️：要先做这步，才能重启！！】
kill -SIGHUP $(pidof dockerd)
检查配置
docker info | grep -i Live
```
应该能看到如下配置

![image.png](https://i.loli.net/2019/11/29/sY31qC4miSgWGHF.png)

重启 docker
systemctl restart docker

注意 
```
重启 docker 后请 disable live-restore ！
```

设置  /etc/docker/daemon.json 参数 live-restore 为 false， "live-restore": false
reload： kill -SIGHUP $(pidof dockerd)
检查：docker info | grep Live，确认是false


### Step 2. 重启直接挂载/var/run/docker.sock的容器

查看该主机上直接挂载 docker.sock 的容器   

docker inspect $(docker ps -q)|grep 'Source.*docker.sock\|Name": "/'|grep sock -B1|grep Name
重启之

【理论分析】
[原因] 因为挂载了/var/run/docker.sock文件，docker机制是绑定主机上该文件的 inode。当docker-engine热重启，该文件的inode改变，所以容器内部所认的这个inode事实上已经木有用了。 所以跟docker.sock相关的功能：容器控制台/容器日志等都无法工作。（例如你的docker的挂载了一个主机文件，当你删除该主机文件并重建之后，docker内部是看不到新文件的！ 如果挂载的是其目录则不会有这个问题。）

### 注意
重启完之后，记得把配置再改回去