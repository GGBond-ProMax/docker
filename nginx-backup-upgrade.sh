#!/bin/bash

# Docker 容器名称
NGINX_DATADIR="/nginxdatadir"
CONF_NAME="${NGINX_DATADIR}/conf"
LOGS_NAME="${NGINX_DATADIR}/logs"
HTML_NAME="${NGINX_DATADIR}/html"
IMAGE_NAME="nginx"             # Docker 镜像名称
NEW_VERSION="1.26.2"           # 新的 Nginx 版本
CONTAINER_NAME="docker-nginx"  # 请确保容器名称正确
NGINX_CONF_DIR="/etc/nginx"    # 容器内 Nginx 的配置目录
BACKUP_DIR="/nginx_backup"     # 备份存放目录
BACKUP_FILE="$BACKUP_DIR/nginx_config_backup_$(date +'%Y%m%d_%H%M%S').tar.gz"
MAX_BACKUP_DAYS=7              # 保留7天内的备份文件

# 创建备份目录（如果不存在）
if [ ! -d "$BACKUP_DIR" ]; then
    echo "创建备份目录 $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
fi

# 定时备份 Docker 容器中 Nginx 配置文件
backup_nginx_conf() {
    # 复制 Nginx 配置文件到备份目录
    echo "正在复制 Nginx 配置文件到 $BACKUP_DIR/nginx_config..."
    cp -r "${CONF_NAME}" "$BACKUP_DIR/nginx_config"

    # 检查 cp 命令是否成功
    if [ $? -ne 0 ]; then
        echo "从目录中复制 Nginx 配置失败，请检查目录权限。"
        exit 1
    else
        echo "Nginx 配置文件成功备份至 $BACKUP_DIR/nginx_config。"
    fi
    
    # 压缩并备份配置文件
    tar -czf "$BACKUP_FILE" -C "$BACKUP_DIR" nginx_config
    if [ $? -ne 0 ]; then
        echo "压缩备份文件失败。"
        exit 1
    fi

    echo "Nginx 配置已备份至：$BACKUP_FILE"
    
    # 删除临时配置目录
    rm -rf "$BACKUP_DIR/nginx_config"
    
    # 清理超过7天的备份
    find "$BACKUP_DIR" -type f -name 'nginx_config_backup_*.tar.gz' -mtime +$MAX_BACKUP_DAYS -exec rm -f {} \;
    echo "已清理 $MAX_BACKUP_DAYS 天前的备份。"
}

# 将备份任务添加到 crontab
add_cron_job() {
    SCRIPT_PATH=$(realpath $0)  # 获取当前脚本的绝对路径
    CRON_JOB="0 2 * * * $SCRIPT_PATH backup"
    
    # 检查是否已存在该 cron 任务
    if crontab -l | grep -q "$SCRIPT_PATH backup"; then
        echo "定时任务已存在。"
    else
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        echo "已将备份任务添加到每日凌晨2点的定时任务。"
    fi
}

# 判断是否是备份任务调用
if [ "$1" == "backup" ]; then
    backup_nginx_conf
    exit 0
fi

# 添加定时备份任务
add_cron_job

# 拉取新的 Nginx 镜像
nginx_upgrade(){
    echo "正在拉取 Nginx $NEW_VERSION 镜像..."
    docker pull "${IMAGE_NAME}:${NEW_VERSION}"

    # 检查现有容器是否在运行并停止它
    if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
        echo "正在停止并删除现有的 Nginx 容器..."
        docker stop "$CONTAINER_NAME"
        docker rm "$CONTAINER_NAME"
    else
        echo "没有正在运行的 Nginx 容器，继续..."
    fi

    # 使用新的 Nginx 镜像启动容器
    echo "正在使用 Nginx $NEW_VERSION 启动新容器..."
    docker run -d --name "$CONTAINER_NAME" -p 80:80 \
        -v "$CONF_NAME:/etc/nginx" \
        -v "$LOGS_NAME:/var/log/nginx" \
        -v "$HTML_NAME:/usr/share/nginx/html" \
        "${IMAGE_NAME}:${NEW_VERSION}"

    echo "Nginx 已升级至 $NEW_VERSION 并启动成功。"
}

# 判断是否是升级任务调用
if [ "$1" == "upgrade" ]; then
    nginx_upgrade
    exit 0
fi
