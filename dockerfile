# 使用Ubuntu 18.04作为基础镜像
FROM ubuntu:18.04

# 设置非交互模式，防止在构建过程中出现提示
ENV DEBIAN_FRONTEND=noninteractive

# 更换Ubuntu源为国内源 (例如使用阿里云的镜像)
RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list

# 更新apt-get源并安装必要的软件包
RUN apt-get update \
    && apt-get install -y \
    libsqlite3-dev libpq-dev python3.8-dev chromium-browser nmap build-essential \
    zlib1g-dev libbz2-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev \
    libreadline-dev libffi-dev wget python-dev libffi-dev \
    python3-dev build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev \
    libssl-dev libreadline-dev libffi-dev wget postgresql-client

# 将python3默认替换为python3.8
RUN ln -sf /usr/bin/python3.8 /usr/bin/python3

# 安装pip并更换pip源为国内源 (例如使用阿里云的镜像)
RUN apt-get update \
    && apt-get install -y python3-pip \
    && mkdir -p ~/.pip \
    && echo "[global]" > ~/.pip/pip.conf \
    && echo "index-url = https://mirrors.aliyun.com/pypi/simple/" >> ~/.pip/pip.conf \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 将watchdog文件夹复制到Docker镜像中
COPY ./watchdog.tar.gz /

RUN tar -zxvf /watchdog.tar.gz -C /home

# 更新pip和setuptools
RUN python3 -m pip install --upgrade pip setuptools

# 手动安装 MarkupSafe
RUN python3 -m pip install MarkupSafe

# 安装watchdog根目录下的requirements.txt中的Python包
RUN python3 -m pip install --no-cache-dir -r /home/watchdog/requirements.txt

# 安装client/subdomain/oneforall目录下的requirements.txt中的Python包
RUN python3 -m pip install --no-cache-dir -r /home/watchdog/client/subdomain/oneforall/requirements.txt

# 设置FLASK_APP环境变量
ENV FLASK_APP=app.py:APP

# 设置工作目录
WORKDIR /home/watchdog

RUN echo '#!/bin/bash\n\
\n\
flask createdb\n\
flask createuser\n\
\n\
# 在后台启动其他进程\n\
nohup python3 -u client/subdomain/oneforall/sbudomain_run.py > /home/logs/dns.log 2>&1 &\n\
nohup python3 -u client/portscan/portscan_run.py > /home/logs/port.log 2>&1 &\n\
nohup python3 -u client/urlscan/url_probe/urlscan_run.py > /home/logs/url.log 2>&1 &\n\
nohup python3 -u client/urlscan/xray/xray_run.py > /home/logs/xray.log 2>&1 &\n\
\n\
# 在前台启动 Flask 应用\n\
python3 -m flask run -p 5001 -h 0.0.0.0' > /home/watchdog/start.sh \
    && chmod +x start.sh

# 使用CMD指令来启动start.sh脚本
CMD ["/home/watchdog/start.sh"]
# CMD ["tail", "-f", "/dev/null"]
