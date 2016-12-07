#!/bin/sh

###################################################################
#                               变量
###################################################################
CUR_DIR=$(pwd)

# 全局变量
RESTY_USER="nginx"
RESTY_GROUP="nginx"

# 源码包
OPENSSL_TAR_PACKAGE="source/openssl-1.0.2j.tar.gz"
ZLIB_TAR_PACKAGE="source/zlib-1.2.8.tar.gz"
PCRE_TAR_PACKAGE="source/pcre-8.39.tar.gz"
OPENRESTY_TAR_PACKAGE="source/openresty-1.11.2.2.tar.gz"

# nginx第三方模块源码
NGINX_UPSTREAM_CHEK_MODULE_PACKAGE="source/module/nginx_upstream_check_module.tar.gz"

RESTY_SOURCE_DIR="/opt/openresty/source" # 源码包将解压到该目录
RESTY_BINARY_DIR="/opt/openresty"        # configure prefix目录
RESTY_LOG_DIR="/var/log/nginx"

RESTY_VERSION="1.11.2.2"
RESTY_OPENSSL_VERSION="1.0.2j"
RESTY_PCRE_VERSION="8.39"
RESTY_ZLIB_VERSION="1.2.8"

RESTY_J="4"

# 第三方依赖
RESTY_3RD_DEPS="--with-openssl=${RESTY_SOURCE_DIR}/openssl-${RESTY_OPENSSL_VERSION} \
				--with-pcre=${RESTY_SOURCE_DIR}/pcre-${RESTY_PCRE_VERSION} \
				--with-zlib=${RESTY_SOURCE_DIR}/zlib-${RESTY_ZLIB_VERSION}"

# 模块参数
RESTY_CONFIG_OPTIONS="--prefix=${RESTY_BINARY_DIR} \
                      --with-luajit \
                      --with-pcre-jit \
                      --with-ipv6 \
                      --with-stream \
                      --with-stream_ssl_module \
                      --with-http_v2_module \
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
                      --with-file-aio \
                      --with-http_ssl_module \
                      --without-mail_pop3_module \
                      --without-mail_imap_module \
                      --without-mail_smtp_module \
                      --add-module=${RESTY_SOURCE_DIR}/nginx_upstream_check_module"


###################################################################
#                               安装流程
###################################################################

# 安装openresty依赖软件包
yum install -y readline-devel gcc

# 创建用户和组
groupadd -r ${RESTY_GROUP}
useradd -r -M -g ${RESTY_GROUP} -s /sbin/nologin -c "nginx server" ${RESTY_USER}

# 解压源码包
mkdir -p ${RESTY_SOURCE_DIR}
tar -xzf ${OPENSSL_TAR_PACKAGE} -C ${RESTY_SOURCE_DIR}
tar -xzf ${ZLIB_TAR_PACKAGE} -C ${RESTY_SOURCE_DIR}
tar -xzf ${PCRE_TAR_PACKAGE} -C ${RESTY_SOURCE_DIR}
tar -xzf ${OPENRESTY_TAR_PACKAGE} -C ${RESTY_SOURCE_DIR}
tar -xzf ${NGINX_UPSTREAM_CHEK_MODULE_PACKAGE} -C ${RESTY_SOURCE_DIR}

# 打nginx补丁
cd ${RESTY_SOURCE_DIR}/openresty-${RESTY_VERSION}/bundle/nginx-1.11.2
patch -p0 < ${RESTY_SOURCE_DIR}/nginx_upstream_check_module/check_1.11.1+.patch

# 编译安装
cd ${RESTY_SOURCE_DIR}/openresty-${RESTY_VERSION}
./configure -j${RESTY_J} ${RESTY_3RD_DEPS} ${RESTY_CONFIG_OPTIONS}
make -j${RESTY_J}
make -j${RESTY_J} install

# 创建nginx lua文件夹
mkdir -p ${RESTY_BINARY_DIR}/nginx/lua

# 创建website文件夹，用于虚拟主机
mkdir -p ${RESTY_BINARY_DIR}/nginx/website

# 复制nginx配置文件
cd ${CUR_DIR}
cp conf/nginx.conf ${RESTY_BINARY_DIR}/nginx/conf
chmod 644 ${RESTY_BINARY_DIR}/nginx/conf/nginx.conf
cp conf/default.conf ${RESTY_BINARY_DIR}/nginx/website
chmod 644 ${RESTY_BINARY_DIR}/nginx/website/default.conf

# 复制systemd
cd ${CUR_DIR}
cp systemd/openresty.service /usr/lib/systemd/system
chmod 644 /usr/lib/systemd/system/openresty.service
systemctl daemon-reload

# 创建日志文件夹
mkdir -p ${RESTY_LOG_DIR}
chown -R ${RESTY_USER}:${RESTY_GROUP} ${RESTY_LOG_DIR}

# 复制logrotate配置文件，用于日志分割
cd ${CUR_DIR}
cp logrotate/logrotate_nginx.conf /etc/logrotate.d
chmod 644 /etc/logrotate.d/logrotate_nginx.conf

# 修改openresty目录权限
chown -R ${RESTY_USER}:${RESTY_GROUP} ${RESTY_BINARY_DIR}