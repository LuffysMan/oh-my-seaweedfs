#!/usr/bin/env bash

# log_util.sh - 通用日志工具
#
# 用法:
#   source log_util.sh                    # 只打印到终端
#   source log_util.sh /var/log/xxx.log   # 同时打印到终端和日志文件
#
# 然后调用:
#   log_info  "message"
#   log_warn  "message"
#   log_error "message"

# 防止重复 source
if [[ -n "${__LOG_UTIL_LOADED:-}" ]]; then
    return 0
fi
__LOG_UTIL_LOADED=1

# 日志文件路径（为空表示只输出到终端）
__LOG_FILE="${1:-}"

# 颜色（仅在终端输出时使用）
__LOG_COLOR_RESET="\033[0m"
__LOG_COLOR_INFO="\033[32m"   # 绿
__LOG_COLOR_WARN="\033[33m"   # 黄
__LOG_COLOR_ERROR="\033[31m"  # 红

# 是否支持颜色：终端 + 有 tty
function __log_use_color() {
    [[ -t 1 ]]
}

# 内部：写日志
# $1 级别, $2 颜色, $3 调用者文件名, $4 调用者行号, $5 内容
function __log_write() {
    local level="$1"
    local color="$2"
    local file="$3"
    local line="$4"
    local msg="$5"

    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')

    local plain="[${ts}] [${level}] [${file}:${line}] ${msg}"

    # 终端输出（带颜色）
    if __log_use_color; then
        printf "%b%s%b\n" "${color}" "${plain}" "${__LOG_COLOR_RESET}"
    else
        printf "%s\n" "${plain}"
    fi

    # 文件输出（无色）
    if [[ -n "${__LOG_FILE}" ]]; then
        printf "%s\n" "${plain}" >> "${__LOG_FILE}"
    fi
}

# 从调用栈中提取调用者的文件名和行号
# 由于被 log_info 等包裹了一层，需要再往外一层
function __log_caller() {
    # BASH_SOURCE[0]=log_util.sh, [1]=log_info, [2]=真正的调用者
    local src="${BASH_SOURCE[2]:-${BASH_SOURCE[1]}}"
    local line="${BASH_LINENO[1]}"
    echo "$(basename "$src"):${line}"
}

function log_info() {
    local caller
    caller=$(__log_caller)
    __log_write "INFO " "${__LOG_COLOR_INFO}" "${caller%%:*}" "${caller##*:}" "$*"
}

function log_warn() {
    local caller
    caller=$(__log_caller)
    __log_write "WARN " "${__LOG_COLOR_WARN}" "${caller%%:*}" "${caller##*:}" "$*"
}

function log_error() {
    local caller
    caller=$(__log_caller)
    __log_write "ERROR" "${__LOG_COLOR_ERROR}" "${caller%%:*}" "${caller##*:}" "$*"
}