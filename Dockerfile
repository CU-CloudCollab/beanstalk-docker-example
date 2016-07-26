FROM ubuntu:12.04

RUN \
  apt-get update && \
  apt-get install -y nginx && \
  echo "daemon off;" >> /etc/nginx/nginx.conf

COPY www /usr/share/nginx/www/

EXPOSE 80

CMD ["/usr/sbin/nginx", "-c", "/etc/nginx/nginx.conf"]