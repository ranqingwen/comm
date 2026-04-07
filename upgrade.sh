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
	export UPDATE_TAG="AutoUpdate-${TARGET_BOARD}"
	export FILESETC_UPDATE="${HOME_PATH}/package/base-files/files/etc/openwrt_update"
	export GITHUB_PROXY="https://ghfast.top"
	export RELEASE_DOWNLOAD="\$GITHUB_LINK/releases/download/${UPDATE_TAG}"
	export GITHUB_RELEASE="${GITHUB_LINK}/releases/tag/${UPDATE_TAG}"
	
	if [[ ! -f "$LINSHI_COMMON/autoupdate/replace" ]]; then
		echo -e "\n\033[0;31m缺少autoupdate/replace文件\033[0m"
		exit 1
	fi

	# --- 核心修复：直接在函数内提取内核版本，不再依赖外部变量 ---
	# 尝试从 include/kernel-version.mk 提取 (6.12.80 这种格式)
	local KERN_V=$(grep -oP '(?<=LINUX_VERSION-6.12 = ).*' "${HOME_PATH}/include/kernel-version.mk" | tr -d ' ')
	
	# 2. 如果上面没匹配到，尝试通用的 LINUX_VERSION 提取
	[ -z "$KERN_V" ] && KERN_V=$(grep "^LINUX_VERSION:=" "${HOME_PATH}/include/kernel-version.mk" | cut -d= -f2 | tr -d ' ')
	
	# 3. 如果还是没有，尝试从 Makefile 提取
	[ -z "$KERN_V" ] && KERN_V=$(grep "KERNEL_PATCHVER:=" "${HOME_PATH}/target/linux/${TARGET_BOARD}/Makefile" | cut -d= -f2 | tr -d ' ')

	# 赋值，确保不为空
	export LINUX_KERNEL="${KERN_V:-6.12}"

	# 识别设备型号
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
	
	case "${TARGET_BOARD}" in
	x86)
		export FIRMWARE_SUFFIX=".img.gz"
		# 格式：源码-版本-内核-型号-时间戳
		export AUTOBUILD_FIRMWARE_UEFI="${SOURCE}-${LUCI_EDITION}-${LINUX_KERNEL}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}"
		export AUTOBUILD_FIRMWARE="${SOURCE}-${LUCI_EDITION}-${LINUX_KERNEL}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}"
	;;
	*)
		export FIRMWARE_SUFFIX=".bin"
		export AUTOBUILD_FIRMWARE="${SOURCE}-${LUCI_EDITION}-${LINUX_KERNEL}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}"
	;;
	esac
	
	export FIRMWARE_VERSION="${SOURCE}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}"

	if [[ "${TARGET_BOARD}" == "x86" ]]; then
		BOOT_TYPE="bios"
		echo "AUTOBUILD_FIRMWARE_UEFI=${AUTOBUILD_FIRMWARE_UEFI}-uefi" >> ${GITHUB_ENV}
		echo "AUTOBUILD_FIRMWARE=${AUTOBUILD_FIRMWARE}-${BOOT_TYPE}" >> ${GITHUB_ENV}
	elif [[ "${FIRMWARE_SUFFIX}" == ".img.gz" ]]; then
		BOOT_TYPE="bios"
		echo "AUTOBUILD_FIRMWARE=${AUTOBUILD_FIRMWARE}-${BOOT_TYPE}" >> ${GITHUB_ENV}
	else
		BOOT_TYPE="sysupgrade"
		echo "AUTOBUILD_FIRMWARE=${AUTOBUILD_FIRMWARE}-${BOOT_TYPE}" >> ${GITHUB_ENV}
	fi

	echo "UPDATE_TAG=${UPDATE_TAG}" >> ${GITHUB_ENV}
	echo "FIRMWARE_SUFFIX=${FIRMWARE_SUFFIX}" >> ${GITHUB_ENV}
	echo "AUTOUPDATE_VERSION=${AUTOUPDATE_VERSION}" >> ${GITHUB_ENV}
	echo "FIRMWARE_VERSION=${FIRMWARE_VERSION}" >> ${GITHUB_ENV}
	echo "GITHUB_RELEASE=${GITHUB_RELEASE}" >> ${GITHUB_ENV}

	# 写入openwrt_update文件
	install -m 0755 /dev/null "${FILESETC_UPDATE}"
	echo "GITHUB_LINK=\"${GITHUB_LINK}\"" >> ${FILESETC_UPDATE}
	echo "FIRMWARE_VERSION=\"${FIRMWARE_VERSION}\"" >> ${FILESETC_UPDATE}
	echo "LUCI_EDITION=\"${LUCI_EDITION}\"" >> ${FILESETC_UPDATE}
	echo "SOURCE=\"${SOURCE}\"" >> ${FILESETC_UPDATE}
	echo "DEVICE_MODEL=\"${TARGET_PROFILE_ER}\"" >> ${FILESETC_UPDATE}
	echo "FIRMWARE_SUFFIX=\"${FIRMWARE_SUFFIX}\"" >> ${FILESETC_UPDATE}
	echo "TARGET_BOARD=\"${TARGET_BOARD}\"" >> ${FILESETC_UPDATE}
	echo "GITHUB_PROXY=\"${GITHUB_PROXY}\"" >> ${FILESETC_UPDATE}
	echo "RELEASE_DOWNLOAD=\"${RELEASE_DOWNLOAD}\"" >> ${FILESETC_UPDATE}
	cat "$LINSHI_COMMON/autoupdate/replace" >> ${FILESETC_UPDATE}

	# 写入del_assets文件
	install -m 0755 /dev/null "${GITHUB_WORKSPACE}/del_assets"
	echo "UPDATE_TAG=\"${UPDATE_TAG}\"" >> "${GITHUB_WORKSPACE}/del_assets"
	echo "BOOT_TYPE=\"${BOOT_TYPE}\"" >> "${GITHUB_WORKSPACE}/del_assets"
	echo "FIRMWARE_SUFFIX=\"${FIRMWARE_SUFFIX}\"" >> "${GITHUB_WORKSPACE}/del_assets"
	echo "FIRMWARE_PROFILEER=\"${SOURCE}-${LUCI_EDITION}-${TARGET_PROFILE_ER}\"" >> "${GITHUB_WORKSPACE}/del_assets"
}

function Diy_Part3() {
	BIN_PATH="${HOME_PATH}/bin/Firmware"
	echo "BIN_PATH=${BIN_PATH}" >> ${GITHUB_ENV}
	[[ ! -d "${BIN_PATH}" ]] && mkdir -p "${BIN_PATH}" || rm -rf "${BIN_PATH}"/*
	
	cd "${FIRMWARE_PATH}"
	# 如果有 .img 但没有 .img.gz，则进行压缩
	if [[ -n "$(ls -1 | grep -Eo '.img')" ]] && [[ -z "$(ls -1 | grep -Eo '.img.gz')" ]]; then
		gzip -f9n *.img
	fi
	
	case "${TARGET_BOARD}" in
	x86)
		# 处理 UEFI 固件
		if [[ -n "$(ls -1 | grep -E 'efi')" ]]; then
			EFI_ZHONGZHUAN="$(ls -1 |grep -Eo ".*squashfs.*efi.*img.gz" |grep -v ".vm\|.vb\|.vh\|.qco\|ext4\|root\|factory\|kernel")"
			if [[ -f "${EFI_ZHONGZHUAN}" ]]; then
				# 移除原有的 EFIMD5 变量及相关拼接，直接使用 Part2 定义的名称
				cp -Rf "${EFI_ZHONGZHUAN}" "${BIN_PATH}/${AUTOBUILD_FIRMWARE_UEFI}${FIRMWARE_SUFFIX}"
				echo "BOOT_UEFI=\"uefi\"" >> "${GITHUB_WORKSPACE}/del_assets"
			else
				echo "没找到在线升级可用的efi${FIRMWARE_SUFFIX}格式固件"
			fi
		fi
		
		# 处理 BIOS (原 legacy) 固件
		if [[ -n "$(ls -1 | grep -E 'squashfs')" ]]; then
			UP_ZHONGZHUAN="$(ls -1 |grep -Eo ".*squashfs.*img.gz" |grep -v ".vm\|.vb\|.vh\|.qco\|efi\|ext4\|root\|factory\|kernel")"
			if [[ -f "${UP_ZHONGZHUAN}" ]]; then
				# 移除原有的 MD5 变量及相关拼接
				cp -Rf "${UP_ZHONGZHUAN}" "${BIN_PATH}/${AUTOBUILD_FIRMWARE}${FIRMWARE_SUFFIX}"
			else
				echo "没找到在线升级可用的${FIRMWARE_SUFFIX}格式固件"
			fi
		else
			echo "没有squashfs格式固件"
		fi
	;;
	*)
		# 其他机型的处理逻辑
		if [[ -n "$(ls -1 | grep -E 'sysupgrade')" ]]; then
			UP_ZHONGZHUAN="$(ls -1 |grep -Eo ".*${TARGET_PROFILE}.*sysupgrade.*${FIRMWARE_SUFFIX}" |grep -v ".vm\|.vb\|.vh\|.qco\|efi\|ext4\|root\|factory\|kernel")"
		elif [[ -n "$(ls -1 | grep -E 'squashfs')" ]]; then
			UP_ZHONGZHUAN="$(ls -1 |grep -Eo ".*${TARGET_PROFILE}.*squashfs.*${FIRMWARE_SUFFIX}" |grep -v ".vm\|.vb\|.vh\|.qco\|efi\|ext4\|root\|factory\|kernel")"
		elif [[ -n "$(ls -1 | grep -E 'combined')" ]]; then
			UP_ZHONGZHUAN="$(ls -1 |grep -Eo ".*${TARGET_PROFILE}.*combined.*${FIRMWARE_SUFFIX}" |grep -v ".vm\|.vb\|.vh\|.qco\|efi\|ext4\|root\|factory\|kernel")"
		elif [[ -n "$(ls -1 | grep -E 'sdcard')" ]]; then
			UP_ZHONGZHUAN="$(ls -1 |grep -Eo ".*${TARGET_PROFILE}.*sdcard.*${FIRMWARE_SUFFIX}" |grep -v ".vm\|.vb\|.vh\|.qco\|efi\|ext4\|root\|factory\|kernel")"
		else
			echo "没找到在线升级可用的${FIRMWARE_SUFFIX}格式固件，或者没适配该机型"
		fi

		if [[ -f "${UP_ZHONGZHUAN}" ]]; then
			# 统一移除哈希值拼接，直接复制
			cp -Rf "${UP_ZHONGZHUAN}" "${BIN_PATH}/${AUTOBUILD_FIRMWARE}${FIRMWARE_SUFFIX}"
		fi
	;;
	esac

	echo -e "\n\033[0;32m远程更新固件\033[0m"
	ls -1 $BIN_PATH
	cd ${HOME_PATH}
}
