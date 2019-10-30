# 云部署脚本

本项目存储我运维的云环境的一些部署脚本

## deploy_aliyun_oss.sh

部署到阿里云的OSS，可以同时刷新CDN。环境变量:

| 变量名                | 是否必填 | 默认值 | 说明                                                                              |
| --------------------- | -------- | ------ | --------------------------------------------------------------------------------- |
| OSS_ACCESS_KEY_ID     | Y        | -      | OSS使用的access key id                                                            |
| OSS_ACCESS_KEY_SECRET | Y        | -      | OSS使用的access key secret                                                        |
| OSS_BUCKET            | Y        | -      | OSS上传的bucket                                                                   |
| BASE_DIR              | N        | dist/  | 本地要上传的目录                                                                  |
| CDN_URL               | N        | -      | 要刷新的CDN URL, 如果给定此选项则`CDN_ACCESS_KEY_ID`和`CDN_ACCESS_KEY_SECRET`必填 |
| CDN_REFRESH_TYPE      | N        | File   | CDN刷新类型，可选`File`/ `Directory`                                              |
| CDN_ACCESS_KEY_ID     | N        | -      | CDN使用的access key id                                                            |
| CDN_ACCESS_KEY_SECRET | N        | -      | CDN使用的access key secret                                                        |
