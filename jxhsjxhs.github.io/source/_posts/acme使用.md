---
title: acme使用
date: 2024-05-09 10:33:46
tags:
index_img: /img/newimg/2024-05-10-10.png
banner_img:  /img/newimg/2024-05-10-10.png
---

最近有需求白嫖免费证书，找了一下基本都推荐[ACME](https://github.com/acmesh-official/acme.sh)。

acme.sh 实现了 acme 协议, 可以从 letsencrypt 生成免费的证书.

主要步骤:

1、安装 acme.sh
```
curl https://get.acme.sh | sh 
```
2、去证书颁发机构去申请账号 https://app.zerossl.com/dashboard
![通过邮箱注册，并且申请key](/img/newimg/2024-05-10-01.png)

编辑 /root/.acme/account.conf 中 ACCOUNT_EMAIL字段。为刚刚注册的邮箱 

![通过邮箱注册，并且申请key](/img/newimg/2024-05-10-02.png)

然后执行绑定token

```
acme.sh --register-account --server zerossl --eab-kid XeKV6sssjfkjlaksdbK6AxZNw --eab-hmac-key f-7eMg4PX15Z3aumWYeyeUsww33FJejp-DyLin4xn2UKtGt4xZNWUrnaklhsdkahskjfalsdjlasdl
```

3、从域名管理厂商拿到相应的api，acme.sh 实现了 acme 协议支持的所有验证协议. 一般有两种方式验证: http 和 dns 验证. 本次文档是通过dns方式证明域名所有权后自动申请证书。
![goggy申请key](/img/newimg/2024-05-10-03.png)
![goggy申请key](/img/newimg/2024-05-10-04.png)

通过环境变量的方式 将刚刚生成的key和Secret导入到环境变量。
```
export GD_Key="key123456"
export GD_Secret="secret123456"
```

4、生成证书
```
泛域名方式：
acme.sh --issue --dns dns_gd -d *.example.com 

多域名方式：
acme.sh --issue --dns dns_gd -d a.example.com  -d  b.example.com   -d c.example.com 
```


5、将证书导出到nginx目录（证书会被定期renew）
```
mkdir -p /etc/nginx/ssl/example.com
acme.sh --install-cert  -d '*.example.com' \
--key-file       /etc/nginx/ssl/example.com/key.pem  \
--fullchain-file /etc/nginx/ssl/example.com/cert.pem \
--reloadcmd     "service nginx force-reload"
```

