FROM ubuntu:16.04

LABEL maintainer="https://github.com/tri-star/lb-nginx" \
      description="A nginx container which alternatives to load balancers."

EXPOSE 80 443

ENV LANG=ja_JP.UTF-8 \
    TZ=Asia/Tokyo \
    TERM=xterm

RUN apt-get update && apt-get install -y logrotate tzdata python-pip git language-pack-ja jq curl vim make gcc libpcre3-dev libssl-dev && \
    update-locale ja_JP.UTF-8 && \
    pip install --upgrade pip && \
    pip install supervisor && \
    pip install awscli && \
    apt-get clean

RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata

RUN cd /usr/local/src && \
    git clone git://github.com/vozlt/nginx-module-vts.git && \
    curl -LO http://nginx.org/download/nginx-1.12.2.tar.gz && \
    tar -zxf nginx-1.12.2.tar.gz && \
    cd nginx-1.12.2 && \
    ./configure --with-http_ssl_module --with-pcre --with-pcre-jit \
    --conf-path=/etc/nginx/nginx.conf \
    --with-threads \
    --with-file-aio \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_gunzip_module \
    --with-http_auth_request_module \
    --with-http_gzip_static_module \
    --with-http_slice_module \
    --with-http_stub_status_module \
    --with-stream \
    --with-mail \
    --with-mail_ssl_module \
    --add-module=/usr/local/src/nginx-module-vts && \
    make && make install && \
    rm /usr/local/src/nginx-1.12.2.tar.gz

# dehydrated install
RUN git clone https://github.com/lukas2511/dehydrated.git /usr/local/letsencrypt && \
    mkdir /usr/local/letsencrypt/well-known

RUN mkdir -p /etc/nginx/conf.d

VOLUME /data /etc/nginx/conf.d


COPY ./letsencrypt /usr/local/letsencrypt
COPY ./gce_fix_ip.sh /gce_fix_ip.sh
COPY ./aws_set_eip.sh /aws_set_eip.sh
COPY ./entry_point.sh /entry_point.sh
COPY ./etc /etc

RUN chmod 644 /etc/cron.d/* && \
    chmod 644 /etc/logrotate.conf && \
    chmod 644 /etc/logrotate.d/* && \
    chmod 755 /entry_point.sh && \
    chmod 755 /gce_fix_ip.sh && \
    chmod 755 /aws_set_eip.sh && \
    chmod 755 /usr/local/letsencrypt/update.sh


ENTRYPOINT ["/entry_point.sh"]
