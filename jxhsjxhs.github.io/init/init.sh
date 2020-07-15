#!/bin/bash
cp  avatar.jpg  ../public/img/
cp  hexo.tar.gz  ../themes
cd ../themes  &&   tar xf  hexo.tar.gz 
hexo g 
touch ../public/CNAME
echo "www.jxhs.me"
