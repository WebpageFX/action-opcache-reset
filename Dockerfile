FROM alpine:3.10

RUN apk add --no-cache openssh

COPY run.sh /run.sh

ENTRYPOINT ["/run.sh"]
