FROM alpine:latest
LABEL MAINTAINER="Feng Yu<abcfy2@163.com>"

RUN apk add --no-cache bash curl openssl file

CMD ["bash"]
