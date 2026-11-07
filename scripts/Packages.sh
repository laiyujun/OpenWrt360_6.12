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
rm -rf feeds/luci/applications/luci-app-unblockneteasemusic
rm -rf feeds/packages/open-app-filter
rm -rf feeds/packages/net/open-app-filter
rm -rf feeds/packages/net/adguardhome
#rm -rf feeds/packages/net/ariang
rm -rf feeds/packages/net/frp
rm -rf feeds/packages/lang/golang

#UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name，可选，pkg为从大杂烩中单独提取包名插件；name为重命名为包名"
UPDATE_PACKAGE "argon" "jerrykuku/luci-theme-argon" "master"
#UPDATE_PACKAGE "argon-config" "jerrykuku/luci-app-argon-config" "master"
UPDATE_PACKAGE "aurora" "eamonxg/luci-theme-aurora" "master"
UPDATE_PACKAGE "aurora-config" "eamonxg/luci-app-aurora-config" "master"
UPDATE_PACKAGE "vantage" "anothaDev/luci-theme-vantage" "main"

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

#luci-app-unblockneteasemusic
UPDATE_PACKAGE "luci-app-unblockneteasemusic" "UnblockNeteaseMusic/luci-app-unblockneteasemusic" "js"

#luci-app-cupsd
#UPDATE_PACKAGE "luci-app-cupsd" "sirpdboy/luci-app-cupsd" "main"

git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang
git clone --depth=1 https://github.com/laipeng668/luci-app-openlist2 package/openlist
#git_sparse_clone ariang https://github.com/laipeng668/packages net/ariang
#git_sparse_clone master https://github.com/coolsnowwolf/luci applications/luci-app-accesscontrol
git clone --depth=1 https://github.com/gdy666/luci-app-lucky luci-app-lucky
git clone --depth=1 https://github.com/NONGFAH/luci-app-athena-led luci-app-athena-led
chmod +x ./luci-app-athena-led/root/etc/init.d/athena_led ./luci-app-athena-led/root/usr/sbin/athena-led

cd "$OPENWRT_PATH" || cd .. || exit
./scripts/feeds update -a
./scripts/feeds install -a

# ============================================================
# 覆盖 ruby：根治 LibWrt 25.12 的 ruby 3.4.9 host 静态链接编译极慢（约 2h+）问题
# 用 immortalwrt/packages master 的 ruby 4.0.7 替换（host 编译仅需 26-41min，已大量设备验证）
# 关键约束：必须在最后一次 feeds install -a 之后执行，否则上方的 feeds update -a 会把替换冲掉
# 兼容性：openclash/passwall 等仅依赖 ruby 包名（PKG_NAME:=ruby），不绑定主版本号，需实跑验证
# 临时禁用：注释掉本段即可回退到 feed 源自带的 ruby 版本
# ============================================================
RUBY_FEED_DIR="feeds/packages/lang/ruby"
if [ -d "$RUBY_FEED_DIR" ]; then
  rm -rf "$RUBY_FEED_DIR"
  rm -rf /tmp/immortalwrt-packages-ruby
  git clone --depth=1 --single-branch --branch master --filter=blob:none --sparse \
    https://github.com/immortalwrt/packages.git /tmp/immortalwrt-packages-ruby
  ( cd /tmp/immortalwrt-packages-ruby && git sparse-checkout set lang/ruby )
  cp -rf /tmp/immortalwrt-packages-ruby/lang/ruby "$RUBY_FEED_DIR"
  rm -rf /tmp/immortalwrt-packages-ruby
  echo "[ruby-override] ruby 已覆盖为 immortalwrt master (4.0.7)，原 feed 版本被替换"
else
  echo "[ruby-override] 未找到 $RUBY_FEED_DIR，跳过 ruby 覆盖"
fi
