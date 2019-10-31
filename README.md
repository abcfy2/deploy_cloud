# 云部署脚本

本项目存储我运维的云环境的一些部署脚本

## deploy_aliyun_oss.sh

部署到阿里云的OSS，可以同时刷新CDN。环境变量:

| 变量名                | 必填 | 默认值                                  | 说明                                                                              |
| --------------------- | ---- | --------------------------------------- | --------------------------------------------------------------------------------- |
| OSS_ACCESS_KEY_ID     | Y    | -                                       | OSS使用的access key id                                                            |
| OSS_ACCESS_KEY_SECRET | Y    | -                                       | OSS使用的access key secret                                                        |
| OSS_BUCKET            | Y    | -                                       | OSS上传的bucket                                                                   |
| OSS_ENDPOINT          | N    | `oss-cn-hangzhou-internal.aliyuncs.com` | OSS的endpoint，默认杭州内网节点                                                   |
| OSS_BASE_PATH         | N    | `/`                                     | 上传到bucket的目录，默认`/`目录                                                   |
| BASE_DIR              | N    | `dist/`                                 | 本地要上传的目录                                                                  |
| CDN_URL               | N    | -                                       | 要刷新的CDN URL, 如果给定此选项则`CDN_ACCESS_KEY_ID`和`CDN_ACCESS_KEY_SECRET`必填 |
| CDN_REFRESH_TYPE      | N    | `File`                                  | CDN刷新类型，可选`File`/ `Directory`                                              |
| CDN_ACCESS_KEY_ID     | N    | -                                       | CDN使用的access key id                                                            |
| CDN_ACCESS_KEY_SECRET | N    | -                                       | CDN使用的access key secret                                                        |

## deploy_tencent_cos.sh

部署到腾讯云的COS，可以同时刷新CDN。环境变量:

| 变量名           | 必填 | 默认值       | 说明                                                                         |
| ---------------- | ---- | ------------ | ---------------------------------------------------------------------------- |
| COS_SECRET_ID    | Y    | -            | COS使用的secret id                                                           |
| COS_SECRET_KEY   | Y    | -            | COS使用的secert key                                                          |
| COS_BUCKET       | Y    | -            | COS使用的bucket                                                              |
| COS_REGION       | N    | `ap-beijing` | COS的region，参考[列表](https://cloud.tencent.com/document/product/436/6224) |
| COS_BASE_PATH    | N    | `/`          | 上传到bucket的目录，默认`/`目录                                              |
| BASE_DIR         | N    | `dist/`      | 本地要上传的目录                                                             |
| CDN_URL          | N    | -            | 要刷新的CDN URL，如果不为空，则`CDN_SECRET_ID`和`CDN_SECRET_KEY`必填         |
| CDN_REFRESH_TYPE | N    | `File`       | CDN刷新类型，可选`File`/`Directory`                                          |
| CDN_SECRET_ID    | N    | -            | CDN使用的 secret id                                                          |
| CDN_SECRET_KEY   | N    | -            | CDN使用的 secret key                                                         |
