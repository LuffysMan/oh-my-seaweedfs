#!/usr/bin/env bash

#############################################################################
# 数据盘自动挂载脚本
# 适用: Ubuntu 22.04
# 功能: 交互式选择数据盘 -> 格式化 ext4 -> 挂载到公共父目录 -> 配置 fstab
#############################################################################

set -euo pipefail

# ============================ 全局变量 ============================
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(dirname ${CURRENT_DIR})"
LOG_FILE="/var/log/disks.log"

# 引入日志工具
# shellcheck source=/dev/null
source "${WORK_DIR}/utils/log_util.sh" "${LOG_FILE}"

# 运行时变量
PARENT_DIR=""            # 用户输入的公共父目录, e.g. /disk
DATA_DISKS=()            # 发现的数据盘列表
MOUNT_INDEX=0            # 挂载目录序号, 用于生成 d1, d2, ...

# ============================ 工具函数 ============================

#######################################
# 检查是否 root 运行
#######################################
check_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        log_error "请使用 root 权限运行此脚本 (sudo $0)"
        exit 1
    fi
    log_info "root 权限检查通过"
}

#######################################
# 检查依赖命令是否存在
#######################################
check_dependencies() {
    local deps=(lsblk blkid mkfs.ext4 mount findmnt awk grep sed)
    local missing=()
    for cmd in "${deps[@]}"; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            missing+=("${cmd}")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "缺少依赖命令: ${missing[*]}"
        exit 1
    fi
    log_info "依赖命令检查通过"
}

#######################################
# 校验父目录: 不存在或为空
# 返回: 0 合法, 1 非法
#######################################
validate_parent_dir() {
    local dir="$1"

    if [[ -z "${dir}" ]]; then
        log_info "父目录不能为空"
        return 1
    fi

    if [[ "${dir}" != /* ]]; then
        log_error "父目录必须是绝对路径: ${dir}"
        return 1
    fi

    if [[ -d "${dir}" ]]; then
        # 目录存在, 检查是否为空
        if [[ -n "$(ls -A "${dir}" 2>/dev/null)" ]]; then
            log_error "目录已存在且非空: ${dir}"
            return 1
        fi
        log_info "目录已存在且为空: ${dir}"
    else
        log_info "目录不存在, 稍后将创建: ${dir}"
    fi

    return 0
}

#######################################
# 交互式获取公共父目录
#######################################
prompt_parent_dir() {
    local input=""
    while true; do
        read -r -p "请输入挂载公共父目录 (default /disk): " input
        if [ -z "${input}" ]; then
            log_info "using default folder: /disk"
            input="/disk"
        fi
        if validate_parent_dir "${input}"; then
            PARENT_DIR="${input}"
            break
        fi
        log_warn "输入无效, 请重新输入"
    done

    # 创建父目录
    if [[ ! -d "${PARENT_DIR}" ]]; then
        mkdir -p "${PARENT_DIR}"
        log_info "已创建父目录: ${PARENT_DIR}"
    fi

    log_info "公共父目录设置为: ${PARENT_DIR}"
}

#######################################
# 发现数据盘 (避开系统盘)
# 判定逻辑:
#   1. 类型为 disk
#   2. 无子分区 (或者将来可扩展)
#   3. 不是根/系统所在盘
#######################################
discover_data_disks() {
    log_info "开始发现数据盘..."

    # 获取系统盘所在设备 (根分区对应的父设备)
    local root_src root_disk
    root_src="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
    # 处理 LVM / 普通分区
    if [[ -n "${root_src}" ]]; then
        root_disk="$(lsblk -no PKNAME "${root_src}" 2>/dev/null || true)"
    fi
    log_info "系统盘设备: ${root_disk:-未知} (根分区: ${root_src:-未知})"

    DATA_DISKS=()
    local disk name type
    while read -r name type; do
        [[ "${type}" != "disk" ]] && continue

        # 跳过系统盘
        if [[ -n "${root_disk}" && "${name}" == "${root_disk}" ]]; then
            log_info "跳过系统盘: /dev/${name}"
            continue
        fi

        # 跳过只读盘/光驱 (可选)
        local ro
        ro="$(lsblk -ndo RO "/dev/${name}" 2>/dev/null || echo 0)"
        if [[ "${ro}" == "1" ]]; then
            log_warn "跳过只读设备: /dev/${name}"
            continue
        fi

        # 跳过已挂载的盘
        local mnt
        mnt="$(lsblk -no MOUNTPOINT "/dev/${name}" 2>/dev/null | awk 'NF{print; exit}')"
        if [[ -n "${mnt}" ]]; then
            log_warn "跳过已挂载设备: /dev/${name} (挂载点: ${mnt})"
            continue
        fi

        DATA_DISKS+=("/dev/${name}")
    done < <(lsblk -ndo NAME,TYPE)

    if [[ ${#DATA_DISKS[@]} -eq 0 ]]; then
        log_warn "未发现可用的数据盘"
        return 1
    fi

    log_info "发现数据盘数量: ${#DATA_DISKS[@]}"
    for d in "${DATA_DISKS[@]}"; do
        log_info "  候选数据盘: ${d} ($(lsblk -ndo SIZE "${d}" 2>/dev/null | tr -d ' '))"
    done
    return 0
}

#######################################
# 交互式确认是否使用某块盘
# 参数: $1 设备路径
# 返回: 0 使用, 1 跳过
#######################################
confirm_use_disk() {
    local dev="$1"
    local size answer
    size="$(lsblk -ndo SIZE "${dev}" 2>/dev/null | tr -d ' ')"
    while true; do
        read -r -p "是否使用数据盘 ${dev} (${size})? [y/N]: " answer
        case "${answer}" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]|"")  return 1 ;;
            *) echo "请输入 y 或 n" ;;
        esac
    done
}

#######################################
# 生成下一个挂载点目录, 如 /disk/d1
# 输出: 挂载点路径
#######################################
next_mount_point() {
    local __outvar="$1"
    MOUNT_INDEX=$((MOUNT_INDEX + 1))
    printf -v "${__outvar}" '%s' "${PARENT_DIR}/d${MOUNT_INDEX}"
}

#######################################
# 检查设备是否已有文件系统
# 参数: $1 设备
# 返回: 0 有, 1 无
#######################################
has_filesystem() {
    local dev="$1"
    local fstype
    fstype="$(blkid -o value -s TYPE "${dev}" 2>/dev/null || true)"
    [[ -n "${fstype}" ]]
}

#######################################
# 格式化设备为 ext4
#######################################
format_disk() {
    local dev="$1"
    log_info "开始格式化 ${dev} 为 ext4 ..."
    if ! mkfs.ext4 -F "${dev}" >>"${LOG_FILE}" 2>&1; then
        log_error "格式化失败: ${dev}"
        return 1
    fi
    log_info "格式化完成: ${dev}"
    return 0
}

#######################################
# 创建挂载点目录
#######################################
create_mount_point() {
    local mnt="$1"
    if [[ -d "${mnt}" ]]; then
        log_warn "挂载点已存在: ${mnt}"
    else
        mkdir -p "${mnt}"
        log_info "已创建挂载点: ${mnt}"
    fi
}

#######################################
# 挂载设备到指定挂载点
#######################################
mount_disk() {
    local dev="$1" mnt="$2"
    if mountpoint -q "${mnt}"; then
        log_warn "${mnt} 已挂载, 跳过"
        return 0
    fi
    if ! mount "${dev}" "${mnt}"; then
        log_error "挂载失败: ${dev} -> ${mnt}"
        return 1
    fi
    log_info "挂载成功: ${dev} -> ${mnt}"
}

#######################################
# 配置 /etc/fstab 开机自动挂载
#######################################
config_fstab() {
    local dev="$1" mnt="$2"
    local uuid fstab_line

    uuid="$(blkid -o value -s UUID "${dev}" 2>/dev/null || true)"
    if [[ -z "${uuid}" ]]; then
        log_error "无法获取 ${dev} 的 UUID, 跳过 fstab 配置"
        return 1
    fi

    fstab_line="UUID=${uuid} ${mnt} ext4 defaults,noatime,nofail 0 2"

    # 幂等: 若已存在相同挂载点则跳过
    if grep -qsE "[[:space:]]${mnt//\//\\/}[[:space:]]" /etc/fstab; then
        log_warn "/etc/fstab 中已存在挂载点 ${mnt} 的配置, 跳过"
        return 0
    fi

    # 备份 fstab
    cp -a /etc/fstab "/etc/fstab.bak.$(date +%Y%m%d%H%M%S)"

    echo "${fstab_line}" >> /etc/fstab
    log_info "已追加 fstab 配置: ${fstab_line}"

    # 验证 fstab 语法
    if ! findmnt --verify --fstab >/dev/null 2>&1; then
        log_warn "fstab 语法验证有警告, 请手动检查 /etc/fstab"
    fi
    return 0
}

#######################################
# 检查设备是否已被挂载
# 参数: $1 设备路径
# 返回: 0 已挂载, 1 未挂载
#######################################
is_disk_mounted() {
    local dev="$1"
    # lsblk 会显示挂载点, 若 MOUNTPOINT 非空则已挂载
    local mnt
    mnt="$(lsblk -no MOUNTPOINT "${dev}" 2>/dev/null | awk 'NF{print; exit}')"
    if [[ -n "${mnt}" ]]; then
        log_warn "设备 ${dev} 已被挂载到: ${mnt}"
        return 0
    fi
    return 1
}

#######################################
# 处理单块数据盘: 确认 -> 格式化 -> 挂载 -> fstab
#######################################
process_disk() {
    local dev="$1"

    if is_disk_mounted "${dev}"; then
        log_warn "跳过已挂载磁盘: ${dev}"
        return 0
    fi

    # 1. 交互式确认
    if ! confirm_use_disk "${dev}"; then
        log_info "用户跳过磁盘: ${dev}"
        return 0
    fi

    # 2. 检查是否已有文件系统
    if has_filesystem "${dev}"; then
        log_warn "${dev} 已存在文件系统, 将跳过格式化 (如需强制格式化请手动执行)"
    else
        if ! format_disk "${dev}"; then
            log_error "跳过磁盘 (格式化失败): ${dev}"
            return 1
        fi
    fi

    # 3. 生成挂载点
    local mnt
    next_mount_point mnt
    create_mount_point "${mnt}"

    # 4. 挂载
    if ! mount_disk "${dev}" "${mnt}"; then
        log_error "跳过磁盘 (挂载失败): ${dev}"
        return 1
    fi

    # 5. 配置 fstab
    config_fstab "${dev}" "${mnt}" || true

    log_info "磁盘处理完成: ${dev} -> ${mnt}"
    return 0
}

#######################################
# 主流程
#######################################
main() {
    log_info "==================== 脚本开始 ===================="

    check_root
    check_dependencies

    # 步骤2: 发现数据盘
    if ! discover_data_disks; then
        log_warn "没有可用数据盘, 脚本退出"
        return 0
    fi

    # 步骤1: 用户交互输入公共父目录
    prompt_parent_dir

    # 步骤3: 遍历数据盘
    local dev
    for dev in "${DATA_DISKS[@]}"; do
        log_info "---------- 处理磁盘: ${dev} ----------"
        process_disk "${dev}" || log_warn "处理磁盘失败, 继续下一块: ${dev}"
    done

    log_info "==================== 脚本结束 ===================="
}

main "$@"