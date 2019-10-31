FROM alpine:latest
LABEL MAINTAINER="Feng Yu<abcfy2@163.com>"

# 不加vim运行openssl会报错: common libcrypto routines:OPENSSL_hexstr2buf:malloc failure:crypto/o_str.c:157, 原因不明"
RUN apk add --no-cache bash curl openssl file vim

CMD ["bash"]
