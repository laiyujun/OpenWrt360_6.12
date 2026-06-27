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

# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
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
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "master" "pkg"
UPDATE_PACKAGE "passwall-packages" "Openwrt-Passwall/openwrt-passwall-packages" "main"
UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg"
UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"
##UPDATE_PACKAGE "ssr-plus" "fw876/helloworld" "master"

UPDATE_PACKAGE "luci-app-gecoosac" "laipeng668/luci-app-gecoosac" "main"

#UPDATE_PACKAGE "luci-app-adguardhome" "xiaoxiao29/luci-app-adguardhome" "master"
UPDATE_PACKAGE "adguardhome" "kenzok8/openwrt-packages" "master" "pkg"
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
UPDATE_PACKAGE "luci-app-accesscontrol" "aige168/luci-app-accesscontrol" "main"

#luci-app-cupsd
#UPDATE_PACKAGE "luci-app-cupsd" "sirpdboy/luci-app-cupsd" "main"

git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang
git clone --depth=1 https://github.com/laipeng668/luci-app-openlist2 package/openlist
#git_sparse_clone ariang https://github.com/laipeng668/packages net/ariang
#git_sparse_clone master https://github.com/coolsnowwolf/luci applications/luci-app-accesscontrol
git clone --depth=1 https://github.com/gdy666/luci-app-lucky luci-app-lucky
git clone --depth=1 https://github.com/NONGFAH/luci-app-athena-led luci-app-athena-led
chmod +x ./luci-app-athena-led/root/etc/init.d/athena_led ./luci-app-athena-led/root/usr/sbin/athena-led

./scripts/feeds update -a
./scripts/feeds install -a
