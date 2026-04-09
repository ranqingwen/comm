#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoBuild Functions
AUTOUPDATE_VERSION=8.0

function Diy_Part1() {
	find . -type d -name 'luci-app-autoupdate' | xargs -i rm -rf {}
        if git clone -q --single-branch --depth=1 --branch=main https://github.com/ranqingwen/luci-app-autoupdate $HOME_PATH/package/luci-app-autoupdate; then
        	if ! grep -q "luci-app-autoupdate" "${HOME_PATH}/include/target.mk"; then
			sed -i 's?DEFAULT_PACKAGES:=?DEFAULT_PACKAGES:=luci-app-autoupdate luci-app-ttyd ?g' ${HOME_PATH}/include/target.mk
		fi
		echo "增加定时更新固件的插件下载完成"
	else
		echo "增加定时更新固件的插件下载失败"
	fi
}

function Diy_Part2() {
    # 1. 统一标签名为 AutoUpdate
    export UPDATE_TAG="AutoUpdate-${TARGET_BOARD}"
    export FILESETC_UPDATE="${HOME_PATH}/package/base-files/files/etc/openwrt_update"
    export GITHUB_PROXY="https://ghfast.top"
    export RELEASE_DOWNLOAD="\$GITHUB_LINK/releases/download/${UPDATE_TAG}"
    export GITHUB_RELEASE="${GITHUB_LINK}/releases/tag/${UPDATE_TAG}"
    
    # 检查必要文件
    if [[ ! -f "$LINSHI_COMMON/autoupdate/replace" ]]; then
        echo -e "\n\033[0;31m缺少autoupdate/replace文件，请检查源码或路径！\033[0m"
        exit 1
    fi

    # 2. 精准识别设备型号
    if [[ "${TARGET_PROFILE}" == *"k3"* ]]; then
        export TARGET_PROFILE_ER="phicomm-k3"
    elif [[ "${TARGET_PROFILE}" == *"k2p"* ]]; then
        export TARGET_PROFILE_ER="phicomm-k2p"
    elif [[ "$TARGET_PROFILE" == *xiaomi* && "$TARGET_PROFILE" == *3g* && "$TARGET_PROFILE" == *v2* ]]; then
        export TARGET_PROFILE_ER="xiaomi_mir3g-v2"
    elif [[ "$TARGET_PROFILE" == *xiaomi* && "$TARGET_PROFILE" == *3g* ]]; then
        export TARGET_PROFILE_ER="xiaomi_mir3g"
    elif [[ "$TARGET_PROFILE" == *xiaomi* && "$TARGET_PROFILE" == *3* && "$TARGET_PROFILE" == *pro* ]]; then
        export TARGET_PROFILE_ER="xiaomi_mi3pro"
    else
        export TARGET_PROFILE_ER="${TARGET_PROFILE}"
    fi
    
    # 3. 固件命名与后缀处理
    case "${TARGET_BOARD}" in
    x86)
        export FIRMWARE_SUFFIX=".img.gz"
        export AUTOBUILD_FIRMWARE_UEFI="${SOURCE}-${LUCI_EDITION}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}"
        export AUTOBUILD_FIRMWARE="${SOURCE}-${LUCI_EDITION}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}"
    ;;
    rockchip | bcm27xx | mxs | sunxi | zynq | loongarch64 | omap | sifiveu | tegra | amlogic | mvebu)
        export FIRMWARE_SUFFIX=".img.gz"
        export AUTOBUILD_FIRMWARE="${SOURCE}-${LUCI_EDITION}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}"
    ;;
    *)
        export FIRMWARE_SUFFIX=".bin"
        export AUTOBUILD_FIRMWARE="${SOURCE}-${LUCI_EDITION}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}"
    ;;
    esac
    
    export FIRMWARE_VERSION="${SOURCE}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}"

    # 4. 引导类型处理
    if [[ "${TARGET_BOARD}" == "x86" ]]; then
        BOOT_TYPE="bios"
        AUTOBUILD_FIRMWARE_UEFI="${AUTOBUILD_FIRMWARE_UEFI}-uefi"
        AUTOBUILD_FIRMWARE="${AUTOBUILD_FIRMWARE}-${BOOT_TYPE}"
        echo "AUTOBUILD_FIRMWARE_UEFI=${AUTOBUILD_FIRMWARE_UEFI}" >> ${GITHUB_ENV}
        echo "AUTOBUILD_FIRMWARE=${AUTOBUILD_FIRMWARE}" >> ${GITHUB_ENV}
    elif [[ "${FIRMWARE_SUFFIX}" == ".img.gz" ]]; then
        BOOT_TYPE="bios"
        AUTOBUILD_FIRMWARE="${AUTOBUILD_FIRMWARE}-${BOOT_TYPE}"
        echo "AUTOBUILD_FIRMWARE=${AUTOBUILD_FIRMWARE}" >> ${GITHUB_ENV}
    else
        BOOT_TYPE="sysupgrade"
        AUTOBUILD_FIRMWARE="${AUTOBUILD_FIRMWARE}-${BOOT_TYPE}"
        echo "AUTOBUILD_FIRMWARE=${AUTOBUILD_FIRMWARE}" >> ${GITHUB_ENV}
    fi

    # 5. 同步关键变量到 GitHub Actions 环境 (确保 Release 标题对齐)
    echo "UPDATE_TAG=${UPDATE_TAG}" >> ${GITHUB_ENV}
    echo "RELEASE_NAME=${UPDATE_TAG}" >> ${GITHUB_ENV} # 核心修改：将标题强制设为 Tag 名
    echo "FIRMWARE_SUFFIX=${FIRMWARE_SUFFIX}" >> ${GITHUB_ENV}
    echo "AUTOUPDATE_VERSION=${AUTOUPDATE_VERSION}" >> ${GITHUB_ENV}
    echo "FIRMWARE_VERSION=${FIRMWARE_VERSION}" >> ${GITHUB_ENV}
    echo "GITHUB_RELEASE=${GITHUB_RELEASE}" >> ${GITHUB_ENV}

    # 6. 写入固件内部配置文件 /etc/openwrt_update
    mkdir -p "$(dirname "${FILESETC_UPDATE}")"
    echo "GITHUB_LINK=\"${GITHUB_LINK}\"" > "${FILESETC_UPDATE}"
    echo "FIRMWARE_VERSION=\"${FIRMWARE_VERSION}\"" >> "${FILESETC_UPDATE}"
    echo "LUCI_EDITION=\"${LUCI_EDITION}\"" >> "${FILESETC_UPDATE}"
    echo "SOURCE=\"${SOURCE}\"" >> "${FILESETC_UPDATE}"
    echo "DEVICE_MODEL=\"${TARGET_PROFILE_ER}\"" >> "${FILESETC_UPDATE}"
    echo "FIRMWARE_SUFFIX=\"${FIRMWARE_SUFFIX}\"" >> "${FILESETC_UPDATE}"
    echo "TARGET_BOARD=\"${TARGET_BOARD}\"" >> "${FILESETC_UPDATE}"
    echo "GITHUB_PROXY=\"${GITHUB_PROXY}\"" >> "${FILESETC_UPDATE}"
    echo "RELEASE_DOWNLOAD=\"${RELEASE_DOWNLOAD}\"" >> "${FILESETC_UPDATE}"
    cat "$LINSHI_COMMON/autoupdate/replace" >> "${FILESETC_UPDATE}"

    # 7. 写入旧固件清理脚本
    echo "UPDATE_TAG=\"${UPDATE_TAG}\"" > "${GITHUB_WORKSPACE}/del_assets"
    echo "BOOT_TYPE=\"${BOOT_TYPE}\"" >> "${GITHUB_WORKSPACE}/del_assets"
    echo "FIRMWARE_SUFFIX=\"${FIRMWARE_SUFFIX}\"" >> "${GITHUB_WORKSPACE}/del_assets"
    echo "FIRMWARE_PROFILEER=\"${SOURCE}-${LUCI_EDITION}-${TARGET_PROFILE_ER}\"" >> "${GITHUB_WORKSPACE}/del_assets"
}

function Diy_Part3() {
    BIN_PATH="${HOME_PATH}/bin/Firmware"
    echo "BIN_PATH=${BIN_PATH}" >> ${GITHUB_ENV}
    [[ ! -d "${BIN_PATH}" ]] && mkdir -p "${BIN_PATH}" || rm -rf "${BIN_PATH}"/*
    
    cd "${FIRMWARE_PATH}"
    # 自动压缩未压缩的 img 文件
    if [[ -n "$(ls -1 | grep -Eo '\.img$')" ]] && [[ -z "$(ls -1 | grep -Eo '\.img\.gz$')" ]]; then
        gzip -f9n *.img
    fi
    
    case "${TARGET_BOARD}" in
    x86)
        # 匹配 UEFI 固件
        if [[ -n "$(ls -1 | grep -E 'efi')" ]]; then
            EFI_ZHONGZHUAN="$(ls -1 | grep -E ".*squashfs.*efi.*img.gz" | grep -v ".vm\|.vb\|.vh\|.qco\|ext4\|root\|factory\|kernel" | head -n 1)"
            if [[ -f "${EFI_ZHONGZHUAN}" ]]; then
                EFIMD5="$(md5sum ${EFI_ZHONGZHUAN} | cut -c1-3)$(sha256sum ${EFI_ZHONGZHUAN} | cut -c1-3)"
                cp -Rf "${EFI_ZHONGZHUAN}" "${BIN_PATH}/${AUTOBUILD_FIRMWARE_UEFI}-${EFIMD5}${FIRMWARE_SUFFIX}"
                echo "BOOT_UEFI=\"uefi\"" >> "${GITHUB_WORKSPACE}/del_assets"
            fi
        fi
        
        # 匹配 BIOS/Standard 固件
        if [[ -n "$(ls -1 | grep -E 'squashfs')" ]]; then
            UP_ZHONGZHUAN="$(ls -1 | grep -E ".*squashfs.*img.gz" | grep -v ".vm\|.vb\|.vh\|.qco\|efi\|ext4\|root\|factory\|kernel" | head -n 1)"
            if [[ -f "${UP_ZHONGZHUAN}" ]]; then
                MD5="$(md5sum ${UP_ZHONGZHUAN} | cut -c1-3)$(sha256sum ${UP_ZHONGZHUAN} | cut -c1-3)"
                cp -Rf "${UP_ZHONGZHUAN}" "${BIN_PATH}/${AUTOBUILD_FIRMWARE}-${MD5}${FIRMWARE_SUFFIX}"
            fi
        fi
    ;;
    *)
        # 通用匹配逻辑
        UP_ZHONGZHUAN=""
        if [[ -n "$(ls -1 | grep -E 'sysupgrade')" ]]; then
            UP_ZHONGZHUAN="$(ls -1 | grep -E ".*${TARGET_PROFILE}.*sysupgrade.*${FIRMWARE_SUFFIX}" | grep -v ".vm\|.vb\|.vh\|.qco\|efi\|ext4\|root\|factory\|kernel" | head -n 1)"
        elif [[ -n "$(ls -1 | grep -E 'squashfs')" ]]; then
            UP_ZHONGZHUAN="$(ls -1 | grep -E ".*${TARGET_PROFILE}.*squashfs.*${FIRMWARE_SUFFIX}" | grep -v ".vm\|.vb\|.vh\|.qco\|efi\|ext4\|root\|factory\|kernel" | head -n 1)"
        elif [[ -n "$(ls -1 | grep -E 'combined')" ]]; then
            UP_ZHONGZHUAN="$(ls -1 | grep -E ".*${TARGET_PROFILE}.*combined.*${FIRMWARE_SUFFIX}" | grep -v ".vm\|.vb\|.vh\|.qco\|efi\|ext4\|root\|factory\|kernel" | head -n 1)"
        elif [[ -n "$(ls -1 | grep -E 'sdcard')" ]]; then
            UP_ZHONGZHUAN="$(ls -1 | grep -E ".*${TARGET_PROFILE}.*sdcard.*${FIRMWARE_SUFFIX}" | grep -v ".vm\|.vb\|.vh\|.qco\|efi\|ext4\|root\|factory\|kernel" | head -n 1)"
        fi

        if [[ -f "${UP_ZHONGZHUAN}" ]]; then
            MD5="$(md5sum ${UP_ZHONGZHUAN} | cut -c1-3)$(sha256sum ${UP_ZHONGZHUAN} | cut -c1-3)"
            cp -Rf "${UP_ZHONGZHUAN}" "${BIN_PATH}/${AUTOBUILD_FIRMWARE}-${MD5}${FIRMWARE_SUFFIX}"
        fi
    ;;
    esac

    # 核心修复点：强制生成 zzz_api 文件并放入固件目录
    if [[ -d "${BIN_PATH}" ]]; then
        echo "${FIRMWARE_VERSION}" > "${BIN_PATH}/zzz_api"
        echo "已本地生成 zzz_api，版本号: ${FIRMWARE_VERSION}"
    fi

    echo -e "\n\033[0;32m远程更新固件准备就绪，包含 zzz_api\033[0m"
    ls -1 "$BIN_PATH"
    cd "${HOME_PATH}"
}