---
title: python3使用sqlit3文档记录
date: 2020-06-12 14:24:45
tags:
---

使用python3内置的sqlite3库，首先连接到数据库，创建并使用游标Cursor，再执行SQL语句，最后提交事务以实现sqlite3数据库中的CRUD新增数据，查询数据，更新数据和删除数据的常用操作。

SQLite是一种嵌入式数据库，它的数据库就是一个文件，SQLite能保存可以保存空值、整数、浮点数、字符串和blob 。sqlite相关教程动手学sqlite。

### 连接数据库(如果不存在则创建)
```
import sqlite3
 
# 连接数据库(如果不存在则创建)
conn = sqlite3.connect('test.db')
print("Opened database successfully")
 
# 创建游标
cursor = conn.cursor()
# 关闭游标
cursor.close()
# 提交事物
conn.commit()

#关闭游标
cursor.close()

#关闭连接
conn.close()
```

### 创建表
```
import sqlite3
 
# 连接数据库(如果不存在则创建)
conn = sqlite3.connect('test.db')

# 创建游标
cursor = conn.cursor()
 
# 创建表
sql = 'CREATE TABLE Student(id integer PRIMARY KEY autoincrement, Name  varchar(30), Age integer)'
cursor.execute(sql)
 
# 提交事物
conn.commit()

#关闭游标
cursor.close()

#关闭连接
conn.close()
```

### 插入数据
```
import sqlite3
 
# 连接数据库(如果不存在则创建)
conn = sqlite3.connect('test.db')

# 创建游标
cursor = conn.cursor()
 
# 插入数据1
sql = "INSERT INTO Student(Name, Age) VALUES('lucy', 22)"
cursor.execute(sql)
 
# 插入数据 2
data = ('jack', 21) 
sql = "INSERT INTO Student(Name, Age) VALUES(?, ?)"
cursor.execute(sql, data)
 
# 提交事物
conn.commit()

#关闭游标
cursor.close()

#关闭连接
conn.close()
```
### 更新记录
```
import sqlite3
 
# 连接数据库(如果不存在则创建)
conn = sqlite3.connect('test.db')

# 创建游标
cursor = conn.cursor()
 
cursor.execute("UPDATE Student SET name = ? where id = ?",("lily","3"))

# 提交事物
conn.commit()

#关闭游标
cursor.close()

#关闭连接
conn.close()
```

### 删除记录
```
import sqlite3
 
# 连接数据库(如果不存在则创建)
conn = sqlite3.connect('test.db')

# 创建游标
cursor = conn.cursor()
 
cursor.execute("delete from Student where id=?",("1",)) #逗号不能省，元组元素只有一个的时候一定要加逗号,将删除lucy

# 提交事物
conn.commit()

#关闭游标
cursor.close()

#关闭连接
conn.close()
```


### 查询数据
```
import sqlite3
 
# 连接数据库(如果不存在则创建)
conn = sqlite3.connect('test.db')

# 创建游标
cursor = conn.cursor()
 
# 查询数据1
sql = "select * from Student"
values = cursor.execute(sql)
for i in values:
    print(i)
 
# 查询数据 2
sql = "select * from Student where id=?"
values = cursor.execute(sql, (1,))
for i in values:
    print('id:', i[0])
    print('name:', i[1])
    print('age:', i[2])
 
# 提交事物
conn.commit()

#关闭游标
cursor.close()

#关闭连接
conn.close()
```

### 删除表格
```
import sqlite3

# 连接数据库(如果不存在则创建)
conn = sqlite3.connect('test.db')

# 创建游标
cursor = conn.cursor()

#删除表格Student
cursor.execute("DROP TABLE Student")

# 提交事物
conn.commit()

#关闭游标
cursor.close()

#关闭连接
conn.close()
```

通过以上的demo可以精炼出函数来执行增删改查。demo如下

### 增加