---
title: 怎么优雅快速激活windows10
date: 2019-11-04 12:06:31
categories: 杂项
tags: windows
---

## 安装windows激活问题
> 每次装windows系统最烦的就是激活,当年小白时候  激活下了四五个软件，什么小马激活啊 旋风激活 等等
> 今天介绍一个方便的激活方法，不需要下软件 直接激活的方法

### KMS
> Key Management Service（简称:KMS），这个功能是在Windows Vista之后的产品中的一种新型产品激活机制，目的是为了Microsoft更好的遏制非法软件授权行为 (但是激活更鸡儿方便了！！！)

### KMS使用方法
> 1. 寻找可用的kms服务器
> 本人自己搭建了一个kms服务器地址为 ss.jxhs.me (docker run -itd -p 1688:1688 luodaoyi/kms-server )
> 目前互联网中可用的kms服务器
> ```
> zh.us.to 有效
> kms.03k.org 有效
> kms.chinancce.com 有效
> kms.shuax.com 有效
> kms.dwhd.org 有效
> kms.luody.info 有效
> kms.digiboy.ir 有效
> kms.lotro.cc 有效
> ss.yechiu.xin 有效
> www.zgbs.cc 有效
> cy2617.jios.org 有效
> ```
> 2.“以管理员身份”打开“MSDOS”窗口，输出命令：slmgr.vbs /upk 按回车进行确定，显示“已成功卸载了产品密钥”
> ![cmd](https://i.loli.net/2019/11/05/suZXGyC9D3Rb2W7.png)
> ![delete](https://i.loli.net/2019/11/05/wZJRd7PyqkmX19K.png)
> 3.输入命令：slmgr /ipk W269N-WFGWX-YVC9B-4J6C9-T83GX        (任意一个win10激活密钥,不行就换)
> ![slmg](https://i.loli.net/2019/11/05/HghASl1XGvW6Msa.png)
> 4.继续输入命令：slmgr /skms ss.jxhs.me  
> ![ss.jxhs.me](https://i.loli.net/2019/11/05/doB1CQUSN2E3VFq.png)
> 5.接下来输入命令：slmgr /ato     窗口提示：“成功的激活了产品”；
> ![激活](https://i.loli.net/2019/11/05/WGA2ejbaQNMiqX1.png)
> 就这么几步就完事了