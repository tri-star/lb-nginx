FROM ubuntu:16.04

LABEL maintainer="https://github.com/tri-star/lb-nginx" \
      description="A nginx container which alternatives to load balancers."

EXPOSE 80 443

ENV LANG=ja_JP.UTF-8 \
    TZ=Asia/Tokyo \
    TERM=xterm

VOLUME /data /etc/nginx/conf.d

RUN apt-get update && apt-get install -y nginx logrotate tzdata python-pip git language-pack-ja jq curl && \
    update-locale ja_JP.UTF-8 && \
    pip install --upgrade pip && \
    pip install supervisor && \
    apt-get clean

RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata

RUN rm -f /etc/nginx/sites-enabled/*

COPY ./gce_fix_ip.sh /gce_fix_ip.sh
COPY ./entry_point.sh /entry_point.sh
COPY ./etc /etc

RUN chmod 644 /etc/cron.d/* && \
    chmod 644 /etc/logrotate.conf && \
    chmod 644 /etc/logrotate.d/* && \
    chmod 755 /entry_point.sh && \
    chmod 755 /gce_fix_ip.sh

ENTRYPOINT ["/entry_point.sh"]
