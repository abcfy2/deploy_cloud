#!/bin/bash -e

_join_by() {
    local IFS="$1"
    shift
    echo "$*"
}

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

_header_deal() {
    local -n headers="${1}" # e.g: ("Host: www.baidu.com" "User-Agent: curl" "x-cos-acl: private")
    IFS=$'\n' sorted_headers=($(sort <<<"${headers[*]}"))
    header_list=()
    http_headers=()
    for kv in "${sorted_headers[@]}"; do
        k="${kv%%: *}"
        v="$(_urlencode "${kv#*: }")"
        header_list+=("${k,,}")
        http_headers+=("${k,,}=${v}")
    done
    echo "$(_join_by ';' "${header_list[@]}")" "$(_join_by '&' "${http_headers[@]}")"
}

_canonical_headers() {
    local -n headers="${1}" # e.g: ("Host: www.baidu.com" "User-Agent: curl" "x-cos-acl: private")
    IFS=$'\n' sorted_headers=($(sort <<<"${headers[*]}"))
    result=""
    for header in "${sorted_headers[@]}"; do
        k="${header%%: *}"
        v="${header#*: }"
        result="${result}${k,,}:${v}
"
    done
    echo "${result}"
}

_signed_headers() {
    local -n headers="${1}" # e.g: ("Host: www.baidu.com" "User-Agent: curl" "x-cos-acl: private")
    IFS=$'\n' sorted_headers=($(sort <<<"${headers[*]}"))
    _header_list=()
    for header in "${sorted_headers[@]}"; do
        k="${header%%: *}"
        v="${header#*: }"
        _header_list+=("${k,,}")
    done
    echo "$(_join_by ';' "${_header_list[@]}")"
}

_hashed_result() {
    local payload="${1}" # e.g {"Limit": 1, "Filters": [{"Values": ["\u672a\u547d\u540d"], "Name": "instance-name"}]}
    echo -n "${payload}" | openssl sha256 -binary | xxd -p -c 100000
}

_url_params_deal() {
    query_string="${1}" # e.g: prefix=example-folder%2F&delimiter=%2F&max-keys=10
    IFS='&' read -ra kv_arr <<<"${query_string}"
    IFS=$'\n' sorted_kv=($(sort <<<"${kv_arr[*]}"))
    key_list=()
    param_list=()
    for kv in "${sorted_kv[@]}"; do
        IFS='=' read -ra kv_split <<<"${kv}"
        k="${kv_split[0]}"
        v="${kv_split[1]}"
        key_list+=("${k,,}")
        param_list+=("${k,,}=${v}")
    done
    url_param_list="$(_join_by ';' "${key_list[@]}")"
    http_parameters="$(_join_by '&' "${param_list[@]}")"
    echo "${url_param_list} ${http_parameters}"
}

_signature() {
    secret_id="${1}"
    secret_key="${2}"
    http_method="${3}"
    uri_path="${4}"
    query="${5}"
    read headerlist headers < <(_header_deal _headers)
    read paramlist params < <(_url_params_deal "${query}")
    http_string="${http_method,,}
${uri_path}
${params}
${headers}
"
    now_ts="$(date +%s)"
    keytime="${now_ts};$((now_ts + 3600))"
    signkey="$(echo -n "${keytime}" | openssl sha1 -binary -hmac "${secret_key}" | xxd -p)"
    http_string_sha1="$(echo -n "${http_string}" | openssl sha1 -binary | xxd -p)"
    string_to_sign="sha1
${keytime}
${http_string_sha1}
"
    signature="$(echo -n "${string_to_sign}" | openssl sha1 -binary -hmac "${signkey}" | xxd -p)"
    echo "q-sign-algorithm=sha1&q-ak=${secret_id}&q-sign-time=${keytime}&q-key-time=${keytime}&q-header-list=${headerlist}&q-url-param-list=${paramlist}&q-signature=${signature}"
}

_tx_rest() {
    host="${1}"
    method="${2}" # e.g: GET / POST / PUT
    path="${3}"
    query="${4}"
    query="${query:+?${query}}"
    upload_file="${5}"
    body="${6}"
    curl_opts=()
    for header in "${_headers[@]}"; do
        [[ "${header}" == Host* ]] || curl_opts+=(-H "${header}")
    done
    [ "${method}" != "GET" ] && request_m="-X ${method}"
    [ -n "${upload_file}" ] && upload_opts=(-T "${upload_file}")
    [ -n "${body}" ] && body_opts=(-d "${body}")
    curl -sSfLk ${request_m} "${curl_opts[@]}" "${upload_opts[@]}" "${body_opts[@]}" "${host}${path}${query}"
    return $?
}

_cos_upload_one_file() {
    file="${1}"
    file="$(echo "${file}" | sed 's@^./@@')"
    secret_id="${COS_SECRET_ID}"
    secret_key="${COS_SECRET_KEY}"
    bucket="${COS_BUCKET}"
    if [ -z "${secret_id}" ] && [ -z "${secret_key}" ] && [ -z "${bucket}" ]; then
        echo "请设置COS_SECRET_ID, COS_SECRET_KEY, COS_BUCKET三个环境变量"
        exit 1
    fi
    upload_path="${COS_BASE_PATH:-/}"
    region="${COS_REGION:-ap-beijing}"
    cos_endpoint="${bucket}.cos.${region}.myqcloud.com"
    request_date="$(LC_ALL=C TZ=GMT date +'%a, %d %b %Y %T %Z')"
    content_md5="$(openssl md5 -binary <"${file}" | base64)"
    extension="${file##*.}"
    file_size="$(stat -c '%s' "${file}")"

    case "${extension,,}" in
    js)
        content_type=application/javascript
        ;;
    css)
        content_type=text/css
        ;;
    json)
        content_type=application/json
        ;;
    ico)
        content_type=image/x-icon
        ;;
    woff)
        content_type=font/woff
        ;;
    woff2)
        content_type=font/woff2
        ;;
    apk)
        content_type=application/vnd.android.package-archive
        ;;
    *)
        content_type=$(file -b --mime-type "${file}")
        ;;
    esac

    _headers=("Host: ${cos_endpoint}"
        "Date: ${request_date}"
        "Content-Length: ${file_size}"
        "Content-Type: ${content_type}"
        "Content-MD5: ${content_md5}")

    storage_path="${upload_path}${file}"
    file_readable_size="$(du -h "${file}" | cut -f1)"
    _http_method='PUT'
    authorization="$(_signature "${secret_id}" "${secret_key}" "${_http_method}" "${storage_path}" "")"
    _headers+=("Authorization: ${authorization}")

    uploading_file_msg="Uploading '${file}' to bucket: '${bucket}' path: '${storage_path}', content-type: '${content_type}', file-size: ${file_readable_size}"
    set +e
    result="$(_tx_rest "https://${cos_endpoint}" "${_http_method}" "${storage_path}" '' "${file}" 2>&1)"
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

export -f _cos_upload_one_file
export -f _signature
export -f _header_deal
export -f _urlencode
export -f _url_params_deal
export -f _join_by
export -f _tx_rest

cos_upload() {
    src="${1}"
    cd "${src}"
    find -type f -print0 | xargs -0 -I{} --no-run-if-empty -P10 bash -ec "_cos_upload_one_file '{}'"
}

tx_cdn_refresh() {
    cdn_refresh_url="${1}"
    secret_id="${CDN_SECRET_ID}"
    secret_key="${CDN_SECRET_KEY}"
    service='cdn'
    if [ -z "${secret_id}" ] && [ -z "${secret_key}" ]; then
        echo "请设置CDN_SECRET_ID，CDN_SECRET_KEY环境变量"
        exit 1
    fi

    _=${CDN_REFRESH_TYPE:=File}
    [ "${CDN_REFRESH_TYPE}" = "File" ] && x_tc_action="PurgeUrlsCache" || x_tc_action="PurgePathCache"
    tx_cdn_endpoint="cdn.tencentcloudapi.com"
    x_tc_timestamp="$(date +%s)"
    x_tc_version="2018-06-06"
    [ "${CDN_REFRESH_TYPE}" = "File" ] &&
        payload="{\"Urls\":[\"${cdn_refresh_url}\"]}" ||
        payload="{\"Paths\":[\"${cdn_refresh_url}\"],\"FlushType\":\"delete\"}"
    _headers=("Host: ${tx_cdn_endpoint}" "Content-Type: application/json; charset=utf-8")

    signed_headers="$(_signed_headers _headers)"
    canonical_headers="$(_canonical_headers _headers)"
    # HTTPRequestMethod + '\n' +
    # CanonicalURI + '\n' +
    # CanonicalQueryString + '\n' +
    # CanonicalHeaders + '\n' +
    # SignedHeaders + '\n' +
    # HashedRequestPayload
    canonical_request="POST
/

${canonical_headers}

${signed_headers}
$(_hashed_result "${payload}")"

    utc_date="$(date --utc -d@"${x_tc_timestamp}" '+%Y-%m-%d')"
    credential_scope="${utc_date}/${service}/tc3_request"
    # Algorithm + \n +
    # RequestTimestamp + \n +
    # CredentialScope + \n +
    # HashedCanonicalRequest
    string_to_sign="TC3-HMAC-SHA256
${x_tc_timestamp}
${credential_scope}
$(_hashed_result "${canonical_request}")"
    secret_date="$(echo -n "${utc_date}" | openssl sha256 -binary -hmac "TC3${secret_key}" | xxd -p -c 100000)"
    secret_service="$(echo -n "${service}" | openssl sha256 -binary -mac HMAC -macopt hexkey:"${secret_date}" | xxd -p -c 100000)"
    secret_signing="$(echo -n "tc3_request" | openssl sha256 -binary -mac HMAC -macopt hexkey:"${secret_service}" | xxd -p -c 100000)"
    signature="$(echo -n "${string_to_sign}" | openssl sha256 -binary -mac HMAC -macopt hexkey:"${secret_signing}" | xxd -p -c 100000)"

    # Algorithm + ' ' +
    # 'Credential=' + SecretId + '/' + CredentialScope + ', ' +
    # 'SignedHeaders=' + SignedHeaders + ', ' +
    # 'Signature=' + Signature
    authorization="TC3-HMAC-SHA256 Credential=${secret_id}/${credential_scope}, SignedHeaders=${signed_headers}, Signature=${signature}"
    _headers+=("X-TC-Action: ${x_tc_action}"
        "X-TC-Timestamp: ${x_tc_timestamp}"
        "X-TC-Version: ${x_tc_version}"
        "Authorization: ${authorization}")

    _tx_rest "https://${tx_cdn_endpoint}" "POST" "/" "" "" "${payload}"
}

main() {
    cos_upload "${BASE_DIR:-dist/}"

    if [ -n "${CDN_URL}" ]; then
        echo "Refreshing CDN: '${CDN_URL}'"
        tx_cdn_refresh "${CDN_URL}"
    fi
}

main
