#!/bin/bash

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local REPO_NAME=$(echo $PKG_REPO | cut -d '/' -f 2)

	rm -rf $(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune)

	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

	if [[ $PKG_SPECIAL == "pkg" ]]; then
		cp -rf $(find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune) ./
		rm -rf ./$REPO_NAME/
	elif [[ $PKG_SPECIAL == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	fi
}

# 移除要替换的包
rm -rf feeds/luci/applications/luci-app-wechatpush
rm -rf feeds/luci/applications/luci-app-appfilter
rm -rf feeds/luci/applications/luci-app-frpc
rm -rf feeds/luci/applications/luci-app-frps
rm -rf feeds/packages/open-app-filter
rm -rf feeds/packages/net/open-app-filter
rm -rf feeds/packages/net/adguardhome
#rm -rf feeds/packages/net/ariang
rm -rf feeds/packages/net/frp
rm -rf feeds/packages/lang/golang

#UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name，可选，pkg为从大杂烩中单独提取包名插件；name为重命名为包名"
UPDATE_PACKAGE "argon" "jerrykuku/luci-theme-argon" "master"
UPDATE_PACKAGE "argon-config" "jerrykuku/luci-app-argon-config" "master"
UPDATE_PACKAGE "alpha" "derisamedia/luci-theme-alpha" "master"
UPDATE_PACKAGE "alpha-config" "animegasan/luci-app-alpha-config" "master"

#UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
UPDATE_PACKAGE "passwall-packages" "Openwrt-Passwall/openwrt-passwall-packages" "main"
UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg"
UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"
##UPDATE_PACKAGE "ssr-plus" "fw876/helloworld" "master"

UPDATE_PACKAGE "luci-app-gecoosac" "lwb1978/openwrt-gecoosac" "main"

UPDATE_PACKAGE "luci-app-adguardhome" "xiaoxiao29/luci-app-adguardhome" "master"
UPDATE_PACKAGE "easymesh" "kenzok8/openwrt-packages" "master" "pkg"
#linkease app
#UPDATE_PACKAGE "ddnsto" "linkease/nas-packages" "master" "pkg"
#UPDATE_PACKAGE "luci-app-ddnsto" "linkease/nas-packages-luci" "main" "pkg"
git clone --depth=1 https://github.com/linkease/istore-ui istore-ui
git clone --depth=1 https://github.com/linkease/istore istore
#iStorex && dependency
UPDATE_PACKAGE "istorex" "linkease/nas-packages-luci" "main" "pkg"
UPDATE_PACKAGE "quickstart" "linkease/nas-packages" "master" "pkg"
UPDATE_PACKAGE "luci-app-quickstart" "linkease/nas-packages-luci" "main" "pkg"
#UPDATE_PACKAGE "istoreenhance" "linkease/nas-packages" "master" "pkg"
#UPDATE_PACKAGE "luci-app-istoreenhance" "linkease/nas-packages-luci" "main" "pkg"

#luci-app-oaf (destan19)
UPDATE_PACKAGE "luci-app-oaf" "destan19/OpenAppFilter" "master"

#luci-app-onliner
UPDATE_PACKAGE "luci-app-onliner" "xuanranran/openwrt-package" "master" "pkg"
#luci-app-accesscontrol
UPDATE_PACKAGE "luci-app-accesscontrol" "NueXini/NueXini_Packages" "main" "pkg"

# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
}
git clone --depth=1 https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/luci-app-openlist2 luci-app-openlist2
#git_sparse_clone ariang https://github.com/laipeng668/packages net/ariang
git clone --depth=1 https://github.com/gdy666/luci-app-lucky luci-app-lucky
git clone --depth=1 https://github.com/NONGFAH/luci-app-athena-led luci-app-athena-led
chmod +x ./luci-app-athena-led/root/etc/init.d/athena_led ./luci-app-athena-led/root/usr/sbin/athena-led

#更新软件包版本
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-not}
	local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	echo " "

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo "$PKG_NAME version update has started!"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Pho 'PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)' $PKG_FILE | head -n 1)
		local PKG_VER=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease|$PKG_MARK)) | first | .tag_name")
		local NEW_VER=$(echo $PKG_VER | sed "s/.*v//g; s/_/./g")
		local NEW_HASH=$(curl -sL "https://codeload.github.com/$PKG_REPO/tar.gz/$PKG_VER" | sha256sum | cut -b -64)

		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")

		echo "$OLD_VER $PKG_VER $NEW_VER $NEW_HASH"

		if [[ $NEW_VER =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
	done
}

#UPDATE_VERSION "软件包名" "测试版，true，可选，默认为否"
#UPDATE_VERSION "sing-box" "true"
#UPDATE_VERSION "tailscale"
