---
title: openresty之ngx-lua指令详解
date: 2021-10-29 22:37:11
tags:
index_img: /img/newimg/008i3skNgy1gvwmjwu7ubj325w0u0gn8.jpg
banner_img: /img/newimg/008i3skNgy1gvwmjwu7ubj325w0u0gn8.jpg
---
最近写openresty 记录一下，经常忘。
### 指令顺序
nginx配置文件中执行lua语句是通过指令来识别的，lua指令执行顺序如下：
![](/img/newimg/008i3skNgy1gvwmi5fg8nj30rx0pawfv.jpg)

### INIT_BY_LUA代码诠释
init_by_lua主要用来执行加载比较耗时的操作。这里通过一个例子来说明：我们在ngx中开辟一个全局变量，并在lua中执行自增操作。
#### NGINX.CONF 的HTTP中写入：
在最后两行，主要意思：

1）、定一个共享内存，内存大小为1m。

2）、init_by_lua_file 指定lua的文件位置，这里一般用来执行一些加载比较耗时的操作，比如连接数据库等。
```
http {
    #include       mime.types;
    default_type  application/octet-stream;
 
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';
 
    access_log  logs/access.log  main;
 
    sendfile        off;
    #tcp_nopush     on;
 
    #keepalive_timeout  0;
    keepalive_timeout  65;
    lua_shared_dict shared_data 1m;
    init_by_lua_file "/Users/stefan/mac_develep/nginx/lua/init.lua";
```

#### INIT.LUA的内容：
```
--load module that spend time
local redis = require "resty.redis"
 
local cjson = require "cjson"
 
--global var
count = 1
--
 
--get share data from ngx
local share_data = ngx.shared.shared_data
 
share_data:set("count", 1)
```