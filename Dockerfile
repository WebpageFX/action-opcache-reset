FROM alpine:3.10

RUN apk add --no-cache openssh

COPY functions.sh run.sh /

CMD ["/run.sh"]
