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
	# 统一标签名为 AutoUpdate
	export UPDATE_TAG="AutoUpdate-${TARGET_BOARD}"
	export FILESETC_UPDATE="${HOME_PATH}/package/base-files/files/etc/openwrt_update"
	export GITHUB_PROXY="https://ghfast.top"
	export RELEASE_DOWNLOAD="\$GITHUB_LINK/releases/download/${UPDATE_TAG}"
	export GITHUB_RELEASE="${GITHUB_LINK}/releases/tag/${UPDATE_TAG}"
	
	if [[ ! -f "$LINSHI_COMMON/autoupdate/replace" ]]; then
		echo -e "\n\033[0;31m缺少autoupdate/replace文件\033[0m"
		exit 1
	fi

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
		# 【修改位置】格式：源码-版本-型号-时间戳 (Lede-24.10-x86-64-...)
		export AUTOBUILD_FIRMWARE_UEFI="${SOURCE}-${LUCI_EDITION}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}"
		export AUTOBUILD_FIRMWARE="${SOURCE}-${LUCI_EDITION}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}"
	;;
	rockchip | bcm27xx | mxs | sunxi | zynq |loongarch64 |omap |sifiveu |tegra |amlogic |mvebu)
		export FIRMWARE_SUFFIX=".img.gz"
		export AUTOBUILD_FIRMWARE="${SOURCE}-${LUCI_EDITION}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}"
	;;
	*)
		export FIRMWARE_SUFFIX=".bin"
		export AUTOBUILD_FIRMWARE="${SOURCE}-${LUCI_EDITION}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}"
	;;
	esac
	
	export FIRMWARE_VERSION="${SOURCE}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}"

	# 引导类型
	if [[ "${TARGET_BOARD}" == "x86" ]]; then
		BOOT_TYPE="legacy"
		echo "AUTOBUILD_FIRMWARE_UEFI=${AUTOBUILD_FIRMWARE_UEFI}-uefi" >> ${GITHUB_ENV}
		echo "AUTOBUILD_FIRMWARE=${AUTOBUILD_FIRMWARE}-${BOOT_TYPE}" >> ${GITHUB_ENV}
	elif [[ "${FIRMWARE_SUFFIX}" == ".img.gz" ]]; then
		BOOT_TYPE="legacy"
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

	# 写入配置
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

	# 写入清理文件
	install -m 0755 /dev/null "${GITHUB_WORKSPACE}/del_assets"
	echo "UPDATE_TAG=\"${UPDATE_TAG}\"" >> "${GITHUB_WORKSPACE}/del_assets"
	echo "BOOT_TYPE=\"${BOOT_TYPE}\"" >> "${GITHUB_WORKSPACE}/del_assets"
	echo "FIRMWARE_SUFFIX=\"${FIRMWARE_SUFFIX}\"" >> "${GITHUB_WORKSPACE}/del_assets"
	# 这里也要同步修改顺序，确保清理逻辑能匹配到
	echo "FIRMWARE_PROFILEER=\"${SOURCE}-${LUCI_EDITION}-${TARGET_PROFILE_ER}\"" >> "${GITHUB_WORKSPACE}/del_assets"
}

function Diy_Part3() {
	BIN_PATH="${HOME_PATH}/bin/Firmware"
	echo "BIN_PATH=${BIN_PATH}" >> ${GITHUB_ENV}
	[[ ! -d "${BIN_PATH}" ]] && mkdir -p "${BIN_PATH}" || rm -rf "${BIN_PATH}"/*
	
	cd "${FIRMWARE_PATH}"
	if [[ -n "$(ls -1 | grep -Eo '.img')" ]] && [[ -z "$(ls -1 | grep -Eo '.img.gz')" ]]; then
		gzip -f9n *.img
	fi
	
	case "${TARGET_BOARD}" in
	x86)
		if [[ -n "$(ls -1 | grep -E 'efi')" ]]; then
			EFI_ZHONGZHUAN="$(ls -1 |grep -Eo ".*squashfs.*efi.*img.gz" |grep -v ".vm\|.vb\|.vh\|.qco\|ext4\|root\|factory\|kernel")"
			if [[ -f "${EFI_ZHONGZHUAN}" ]]; then
				# 计算并拼接 MD5 (3位md5+3位sha256)
				EFIMD5="$(md5sum ${EFI_ZHONGZHUAN} |cut -c1-3)$(sha256sum ${EFI_ZHONGZHUAN} |cut -c1-3)"
				cp -Rf "${EFI_ZHONGZHUAN}" "${BIN_PATH}/${AUTOBUILD_FIRMWARE_UEFI}-${EFIMD5}${FIRMWARE_SUFFIX}"
				echo "BOOT_UEFI=\"uefi\"" >> "${GITHUB_WORKSPACE}/del_assets"
			fi
		fi
		
		if [[ -n "$(ls -1 | grep -E 'squashfs')" ]]; then
			UP_ZHONGZHUAN="$(ls -1 |grep -Eo ".*squashfs.*img.gz" |grep -v ".vm\|.vb\|.vh\|.qco\|efi\|ext4\|root\|factory\|kernel")"
			if [[ -f "${UP_ZHONGZHUAN}" ]]; then
				MD5="$(md5sum ${UP_ZHONGZHUAN} | cut -c1-3)$(sha256sum ${UP_ZHONGZHUAN} | cut -c1-3)"
				cp -Rf "${UP_ZHONGZHUAN}" "${BIN_PATH}/${AUTOBUILD_FIRMWARE}-${MD5}${FIRMWARE_SUFFIX}"
			fi
		fi
	;;
	*)
		# 通用匹配逻辑
		if [[ -n "$(ls -1 | grep -E 'sysupgrade')" ]]; then
			UP_ZHONGZHUAN="$(ls -1 |grep -Eo ".*${TARGET_PROFILE}.*sysupgrade.*${FIRMWARE_SUFFIX}" |grep -v ".vm\|.vb\|.vh\|.qco\|efi\|ext4\|root\|factory\|kernel")"
		elif [[ -n "$(ls -1 | grep -E 'squashfs')" ]]; then
			UP_ZHONGZHUAN="$(ls -1 |grep -Eo ".*${TARGET_PROFILE}.*squashfs.*${FIRMWARE_SUFFIX}" |grep -v ".vm\|.vb\|.vh\|.qco\|efi\|ext4\|root\|factory\|kernel")"
		elif [[ -n "$(ls -1 | grep -E 'combined')" ]]; then
			UP_ZHONGZHUAN="$(ls -1 |grep -Eo ".*${TARGET_PROFILE}.*combined.*${FIRMWARE_SUFFIX}" |grep -v ".vm\|.vb\|.vh\|.qco\|efi\|ext4\|root\|factory\|kernel")"
		elif [[ -n "$(ls -1 | grep -E 'sdcard')" ]]; then
			UP_ZHONGZHUAN="$(ls -1 |grep -Eo ".*${TARGET_PROFILE}.*sdcard.*${FIRMWARE_SUFFIX}" |grep -v ".vm\|.vb\|.vh\|.qco\|efi\|ext4\|root\|factory\|kernel")"
		fi

		if [[ -f "${UP_ZHONGZHUAN}" ]]; then
			MD5="$(md5sum ${UP_ZHONGZHUAN} | cut -c1-3)$(sha256sum ${UP_ZHONGZHUAN} | cut -c1-3)"
			cp -Rf "${UP_ZHONGZHUAN}" "${BIN_PATH}/${AUTOBUILD_FIRMWARE}-${MD5}${FIRMWARE_SUFFIX}"
		fi
	;;
	esac
	echo -e "\n\033[0;32m远程更新固件准备就绪\033[0m"
	ls -1 $BIN_PATH
	cd ${HOME_PATH}
}