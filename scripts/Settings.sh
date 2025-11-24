#!/bin/bash

#IP
WRT_IP=192.168.10.1
#hostname
WRT_HOSTNAME=OpenWrt
#ssid
WRT_WIFI=OpenWrt
#修改默认主题为luci-theme-argon
sed -i "s/luci-theme-bootstrap/luci-theme-argon/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_CI-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")
#修改默认WIFI名
sed -i "s/\.ssid=.*/\.ssid=$WRT_WIFI/g" $(find ./package/kernel/mac80211/ ./package/network/config/ -type f -name "mac80211.*")

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_HOSTNAME'/g" $CFG_FILE

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
  echo "手动调整的插件$WRT_PACKAGE".
	echo "CONFIG_PACKAGE_$WRT_PACKAGE=y" >> ./.config
fi

echo "init settings end."
#exit 0
