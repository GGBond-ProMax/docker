#!/bin/bash

# 设置镜像和容器名称
IMAGE_NAME="nginx:1.26.2"
CONTAINER_NAME="docker-nginx"
NGINX_DATADIR="/nginxdatadir"
CONF_NAME="${NGINX_DATADIR}/conf"
LOGS_NAME="${NGINX_DATADIR}/logs"
HTML_NAME="${NGINX_DATADIR}/html"

# 检查是否已经安装 Docker
if ! command -v docker &> /dev/null
then
    echo "Docker 未安装，请先安装 Docker。"
    exit 1
fi

# 检查 nginxdatadir 目录是否存在，不存在则创建
if [ ! -d "$NGINX_DATADIR" ]; then
    echo "创建目录 $NGINX_DATADIR..."
    mkdir -p "$NGINX_DATADIR"
fi

# 检查并移动 conf、logs、html 目录到 nginxdatadir
if [ -d "./conf" ]; then
    echo "移动 conf 目录到 $NGINX_DATADIR..."
    mv ./conf "$NGINX_DATADIR/"
fi

if [ -d "./logs" ]; then
    echo "移动 logs 目录到 $NGINX_DATADIR..."
    mv ./logs "$NGINX_DATADIR/"
fi

if [ -d "./html" ]; then
    echo "移动 html 目录到 $NGINX_DATADIR..."
    mv ./html "$NGINX_DATADIR/"
fi

# 设置目录权限
chmod -R 777 /nginxdatadir

# 使用 sed 替换第一个出现的 html 路径为 /usr/share/nginx/html
sed -i 's/html/\/usr\/share\/nginx\/html/' "${CONF_NAME}/nginx.conf"

# 拉取 Docker 镜像
echo "正在拉取 Docker 镜像..."
docker pull $IMAGE_NAME

# 删除已存在的容器（如果存在）
if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    echo "删除已有的 Docker 容器..."
    docker rm -f $CONTAINER_NAME
fi

# 运行 Docker 容器
echo "正在运行 Docker 容器..."
docker run -d --name $CONTAINER_NAME -p 80:80  \
           -v "$CONF_NAME:/etc/nginx" \
           -v "$LOGS_NAME:/var/log/nginx" \
           -v "$HTML_NAME:/usr/share/nginx/html" \
           ${IMAGE_NAME}
echo "Nginx Docker 容器已启动并运行在端口 80。"

