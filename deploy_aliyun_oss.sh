#!/bin/bash -e

_urlencode() {
    # urlencode <string>
    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C
    length="${#1}"
    for ((i = 0; i < length; i++)); do
        local c="${1:i:1}"
        case $c in
        [a-zA-Z0-9.~_-]) printf "$c" ;;
        *) printf '%%%02X' "'$c" ;;
        esac
    done
    LC_COLLATE=$old_lc_collate
}

_ali_nonce() {
    date +"%s%N"
}

_timestamp() {
    date -u +"%Y-%m-%dT%H%%3A%M%%3A%SZ"
}

_ali_urlencode() {
    _str="$1"
    _str_len=${#_str}
    _u_i=1
    while [ "$_u_i" -le "$_str_len" ]; do
        _str_c="$(printf "%s" "$_str" | cut -c "$_u_i")"
        case $_str_c in [a-zA-Z0-9.~_-])
            printf "%s" "$_str_c"
            ;;
        *)
            printf "%%%02X" "'$_str_c"
            ;;
        esac
        _u_i="$(($_u_i + 1))"
    done
}

_ali_signature() {
    sorted_query=$(printf "%s" "${query}" | tr '&' '\n' | sort | paste -s -d '&')
    string_to_sign=$(printf "%s" "GET&%2F&$(_ali_urlencode "${sorted_query}")")
    signature=$(printf "%s" "${string_to_sign}" | openssl sha1 -binary -hmac "${ACCESS_KEY_SECRET}&" | base64)

    _ali_urlencode "${signature}"
}

aliyun_request_builder() {
    query="Format=json&AccessKeyId=${ACCESS_KEY_ID}&SignatureMethod=HMAC-SHA1&SignatureVersion=1.0&Version=${version}"
    query="${query}&SignatureNonce=$(_ali_nonce)&Timestamp=$(_timestamp)"

    for q in "$@"; do
        query="${query}&${q%%=*}=$(_ali_urlencode "${q#*=}")"
    done

    query="${query}&Signature=$(_ali_signature "${query}")"
    echo "${query}"
}

aliyun_rest() {
    query="${1}"
    curl -fs "${aliyun_endpoint}?${query}"
}

aliyun_cdn_refresh() {
    ACCESS_KEY_ID="${CDN_ACCESS_KEY_ID}"
    ACCESS_KEY_SECRET="${CDN_ACCESS_KEY_SECRET}"
    if [ -z "${ACCESS_KEY_ID}" ] && [ -z "${ACCESS_KEY_SECRTE}" ]; then
        echo "请设置CDN_ACCESS_KEY_ID，CDN_ACCESS_KEY_SECRET环境变量"
        exit 1
    fi

    aliyun_endpoint="https://cdn.aliyuncs.com/"
    version="2018-05-10"
    request_query="$(aliyun_request_builder \
        Action=RefreshObjectCaches \
        "ObjectPath=${1}" \
        ObjectType=${CDN_REFRESH_TYPE:-File})"

    aliyun_rest "${request_query}"
}

_oss_upload_one_file() {
    file="${1}"
    if [ -z "${OSS_ACCESS_KEY_ID}" ] && [ -z "${OSS_ACCESS_KEY_SECRET}" ] && [ -z "${OSS_BUCKET}" ]; then
        echo "请设置OSS_ACCESS_KEY_ID, OSS_ACCESS_KEY_SECRET, OSS_BUCKET三个环境变量"
        exit 1
    fi
    upload_path="${OSS_BASE_PATH:-/}"
    oss_endpoint="${OSS_ENDPOINT:-oss-cn-hangzhou-internal.aliyuncs.com}"
    host="${OSS_BUCKET}.${oss_endpoint}"
    Date="$(LC_ALL=C TZ=GMT date +'%a, %d %b %Y %T %Z')"
    Content_MD5="$(openssl md5 -binary <"${file}" | base64)"
    extension="${file##*.}"

    case "${extension,,}" in
    js)
        Content_Type=application/javascript
        ;;
    css)
        Content_Type=text/css
        ;;
    json)
        Content_Type=application/json
        ;;
    woff)
        Content_Type=font/woff
        ;;
    woff2)
        Content_Type=font/woff2
        ;;
    apk)
        Content_Type=application/vnd.android.package-archive
        ;;
    *)
        Content_Type=$(file -b --mime-type "${file}")
        ;;
    esac

    storage_path="${upload_path}${file}"
    CanonicalizedResource="/${OSS_BUCKET}${storage_path}"
    SignString="PUT\n${Content_MD5}\n${Content_Type}\n${Date}\n${CanonicalizedResource}"
    Signature=$(echo -ne "$SignString" | openssl sha1 -binary -hmac "${OSS_ACCESS_KEY_SECRET}" | base64)
    Authorization="OSS ${OSS_ACCESS_KEY_ID}:${Signature}"
    file_size="$(du -h "${file}" | cut -f 1)"

    uploading_file_msg="Uploading '${file}' to bucket: '${OSS_BUCKET}' path: '${storage_path}', content-type: '${Content_Type}', file-size: ${file_size}"
    set +e
    result="$(curl -XPUT -sSfLkT "${file}" \
        -H "Content-Type: ${Content_Type}" \
        -H "Date: ${Date}" -H "Content-Md5: ${Content_MD5}" \
        -H "Authorization: ${Authorization}" "https://${host}${storage_path}" 2>&1)"
    error_code=$?
    set -e

    if [ ${error_code} -eq 0 ]; then
        echo "${uploading_file_msg} success"
    else
        echo "${uploading_file_msg} failed, reason:
${result}"
        return ${error_code}
    fi
}

export -f _oss_upload_one_file

oss_upload() {
    src="${1}"
    cd "${src}"
    find -type f -printf "%P\0" | xargs -0 -I{} --no-run-if-empty -P10 bash -ec "_oss_upload_one_file '{}'"
}

main() {
    oss_upload "${BASE_DIR:-dist/}"

    if [ -n "${CDN_URL}" ]; then
        echo "Refreshing CDN: '${CDN_URL}'"
        aliyun_cdn_refresh "${CDN_URL}"
    fi
}

main
