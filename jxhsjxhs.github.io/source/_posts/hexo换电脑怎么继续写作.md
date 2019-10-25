---
title: hexo换电脑怎么继续写作
date: 2019-10-25 00:00:32
categories: 杂项 
tags: hexo
---

惭愧 -- 博客写了俩月才想到这个话题，换电脑了咋继续写博客。

---
### 首先说说我写博客用的东西：
> 1. 博客使用hexo，使用3-hexo主题
> 2. 我把博客代码跟编译出来的静态页面分为两个仓库。写完以后分别提交。
> ![git仓库](https://tva1.sinaimg.cn/large/006y8mN6gy1g8aut185bdj309d026dft.jpg)

### 正文来了
> 1. 走了的好多弯路，一开始博客的图片用的都是本地图片，第一是加载慢。并且换电脑以后 用hexo g && hexo s  居然显示不了图片。
> 2. 然后图片就换了图床---(这里推荐一个mac下的图床工具ipic,免费 好用)利用的是新浪的图床  也不知道能用多久。。打算自己用oss搭建一个图床
> ![图床软件](https://tva1.sinaimg.cn/large/006y8mN6gy1g8avadnznpj306205z756.jpg)
---
### 真的正文
> 1. 安装必要软件
>  git  nodejs  
> 2. github免密
> 3. 拷贝之前的电脑的以下文件(git clone也行 但是一般比较慢)
> _config.yml  package.json   scaffolds/    source/    themes/
> 4. 在新的电脑上执行  npm install hexo-cli -g
> 5. 进入新电脑中想放博客代码的目录，把步骤三中拷贝的文件放入其中
> 6. 执行以下命令

---

``` 
npm install
npm install hexo-deployer-git --save  // 文章部署到 git 的模块
(下面为选择安装)
npm install hexo-generator-feed --save  // 建立 RSS 订阅
npm install hexo-generator-sitemap --save // 建立站点地图
```

### 测试
这时候使用 hexo s 基本可以看到你新添加的文章了。

```
部署发布文章
hexo clean   // 清除缓存 网页正常情况下可以忽略此条命令
hexo g       // 生成静态网页
hexo d       // 开始部署
```
