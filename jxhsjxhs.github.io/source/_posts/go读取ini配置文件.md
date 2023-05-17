---
title: go读取ini配置文件
date: 2023-05-11 23:37:47
tags:
index_img: /img/newimg/72f21e37b858caac34d40731a3185b6.jpg
banner_img: /img/newimg/a52de59facf627c93c0341afca0586b.jpg
---

回顾一下go的知识，防止忘记。
平时写项目都是习惯于将什么Mysql，Redis，Kafka等这些需要配置的配置信息单独用一个conf文件来进行存放，以便管理。
本文主要输出go的ini配置文件的使用。
主要库  `gopkg.in/ini.v1`

使用方法：

首先定义我们的配置文件，例如：
```
cat  config.ini

[database]
Db = mysql
DbHost = 127.0.0.1
DbPort = 3306
DbUser = root
DbPassWord = ******
DbName = ****

[kafka]
address =127.0.0.1:9092
topic = web_log

[collect]
logfile_path =d:\logs\s4.log
```

方法一： 简单使用
```
// 读取配置文件
file, err := ini.Load("conf/config.ini")
if err != nil {
	fmt.Println("配置文件读取错误，请检查文件路径:", err)
}
// 获取配置文件内容
	DbHost = file.Section("database").Key("DbHost").String()
	DbPort = file.Section("database").Key("DbPort").String()
	DbUser = file.Section("database").Key("DbUser").String()
	DbPassWord = file.Section("database").Key("DbPassWord").String()
	DbName = file.Section("database").Key("DbName").String()
	fmt.Println(DbHost, DbPort, DbUser, DbPassWord, DbName)
// 127.0.0.1 3306 root 123456 ginblog

```
也可以映射到结构体，直接获取。
```
# 创建结构体 
type KafkaConfig struct {
	Address string `ini:"address"`
	Topic   string `ini:"topic"`
}

type Collect struct {
	LogFilePath string `ini:"logfile_path"`
}

type Database struct {
	Db         string `ini:"Db"`
	DbHost     string `ini:"DbHost"`
	DbPort     string `ini:"DbPort"`
	DbUser     string `ini:"DbUser"`
	DbPassWord string `ini:"DbPassWord"`
	DbName     string `ini:"DbName"`
}

# 实例化
    database := Database{
		file.Section("database").Key("Db").String(),
		file.Section("database").Key("DbHost").String(),
		file.Section("database").Key("DbPort").String(),
		file.Section("database").Key("DbUser").String(),
		file.Section("database").Key("DbPassWord").String(),
		file.Section("database").Key("DbName").String(),
	}
	collect := Collect{
		file.Section("collect").Key("logfile_path").String(),
	}
	kafka := KafkaConfig{
		file.Section("kafka").Key("address").String(),
		file.Section("kafka").Key("topic").String(),
	}   
```
![获取方式1](/img/newimg/f61aa1e12605c43eaa89c7137208d9c.png)

方法二：结构体反射

还是同样的配置文件

```
# 首先定义好结构体，跟配置文件对应
type Config struct {
	KafkaConfig `ini:"kafka"`
	Collect     `ini:"collect"`
	Database    `ini:"database"`
}

type KafkaConfig struct {
	Address string `ini:"address"`
	Topic   string `ini:"topic"`
}

type Collect struct {
	LogFilePath string `ini:"logfile_path"`
}

type Database struct {
	Db         string `ini:"Db"`
	DbHost     string `ini:"DbHost"`
	DbPort     int    `ini:"DbPort"`
	DbUser     string `ini:"DbUser"`
	DbPassWord string `ini:"DbPassWord"`
	DbName     string `ini:"DbName"`
}
# 获取方法
func main() {
	var configObj = new(Config)
	err := ini.MapTo(configObj, "./config.ini")
	if err != nil {
		logrus.Error("config failed err:", err)
		return
	}
	fmt.Println(configObj.Database.Db)

}

```
![获取方式2](/img/newimg/a52de59facf627c93c0341afca0586b.jpg)
