---
title: 编译安装openresty
date: 2024-05-22 18:30:18
tags:
index_img: /img/newimg/2024-05-22-01.png
banner_img: /img/newimg/2024-05-22-01.png
---
## OpenResty 源码编译安装脚本：
如果是debian系  yum改成apt-get
``` bash
#!/bin/bash
set -e

zlib_version=1.3.1
pcre_version=8.45
openssl_version=1.1.1t
openresty_version=1.25.3.1


# 版本自己看着来 主要是openresty的版本
openssl_prefix=/usr/local/openresty/openssl111
zlib_prefix=/usr/local/openresty/zlib
pcre_prefix=/usr/local/openresty/pcre
openresty_prefix=/usr/local/openresty


yum install -y ccache bzip2 patch gcc make  
mkdir openresty-source
cd openresty-source

wget https://github.com/madler/zlib/releases/download/v${zlib_version}/zlib-${zlib_version}.tar.xz
wget https://sourceforge.net/projects/pcre/files/pcre/${pcre_version}/pcre-${pcre_version}.tar.bz2
wget https://www.openssl.org/source/openssl-${openssl_version}.tar.gz
wget https://raw.githubusercontent.com/openresty/openresty/master/patches/openssl-1.1.1f-sess_set_get_cb_yield.patch
wget https://openresty.org/download/openresty-${openresty_version}.tar.gz


tar -xJf zlib-${zlib_version}.tar.xz
cd zlib-${zlib_version}
./configure --prefix=${zlib_prefix}
make -j`nproc` CFLAGS='-O3 -fPIC -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -g3' \
    SFLAGS='-O3 -fPIC -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -g3' \
    > /dev/stderr
make install
cd ..


tar -xjf pcre-${pcre_version}.tar.bz2
cd pcre-${pcre_version}
export CC="ccache gcc -fdiagnostics-color=always"
./configure \
  --prefix=${pcre_prefix} \
  --libdir=${pcre_prefix}/lib \
  --disable-cpp \
  --enable-jit \
  --enable-utf \
  --enable-unicode-properties
make -j`nproc` V=1 > /dev/stderr
make install
cd ..

tar zxf openssl-${openssl_version}.tar.gz
cd openssl-${openssl_version}/
patch -p1 <  ../openssl-1.1.1f-sess_set_get_cb_yield.patch

./config \
    shared zlib -g3 \
    enable-camellia enable-seed enable-rfc3779 \
    enable-cms enable-md2 enable-rc5 \
    enable-weak-ssl-ciphers \
    enable-ssl3 enable-ssl3-method \
    --prefix=${openssl_prefix} \
    --libdir=lib \
    -I${zlib_prefix}/include \
    -L${zlib_prefix}/lib \
    -Wl,-rpath,${zlib_prefix}/lib:${openssl_prefix}/lib

make CC='ccache gcc -fdiagnostics-color=always' -j`nproc`
make install
cd ..

# 插件看需求
tar zxf openresty-${openresty_version}.tar.gz
cd openresty-${openresty_version}
./configure \
--prefix="${openresty_prefix}" \
--with-cc='ccache gcc -fdiagnostics-color=always' \
--with-cc-opt="-DNGX_LUA_ABORT_AT_PANIC -I${zlib_prefix}/include -I${pcre_prefix}/include -I${openssl_prefix}/include" \
--with-ld-opt="-L${zlib_prefix}/lib -L${pcre_prefix}/lib -L${openssl_prefix}/lib -Wl,-rpath,${zlib_prefix}/lib:${pcre_prefix}/lib:${openssl_prefix}/lib" \
--with-pcre-jit \
--without-http_rds_json_module \
--without-http_rds_csv_module \
--without-lua_rds_parser \
--with-stream \
--with-stream_ssl_module \
--with-stream_ssl_preread_module \
--with-http_v2_module \
--without-mail_pop3_module \
--without-mail_imap_module \
--without-mail_smtp_module \
--with-http_stub_status_module \
--with-http_realip_module \
--with-http_addition_module \
--with-http_auth_request_module \
--with-http_secure_link_module \
--with-http_random_index_module \
--with-http_gzip_static_module \
--with-http_sub_module \
--with-http_dav_module \
--with-http_flv_module \
--with-http_mp4_module \
--with-http_gunzip_module \
--with-threads \
--with-compat \
--with-luajit-xcflags='-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT' \
-j`nproc`

make -j`nproc`
make install
cd ..

cat <<EOF > /etc/systemd/system/openresty.service
[Unit]
Description=The nginx HTTP and reverse proxy server
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/usr/local/openresty/nginx/logs/nginx.pid
ExecStartPre=/usr/bin/rm -f /usr/local/openresty/nginx/logs/nginx.pid
ExecStartPre=/usr/local/openresty/nginx/sbin/nginx -t
ExecStart=/usr/local/openresty/nginx/sbin/nginx
ExecReload=/bin/kill -s HUP $MAINPID
KillSignal=SIGQUIT
TimeoutStopSec=5
KillMode=process
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

chmod 644 /etc/systemd/system/openresty.service
systemctl daemon-reload
systemctl enable openresty.service
systemctl start openresty.service
systemctl status openresty.service

```
