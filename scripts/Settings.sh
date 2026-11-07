#!/bin/bash

#IP
WRT_IP=192.168.10.1
#hostname
WRT_HOSTNAME=OpenWrt
#ssid
WRT_SSID=OpenWrt
#wifi pwd
WRT_PWD=12345678
#theme
WRT_THEME=argon

# 移除luci-app-attendedsysupgrade软件包
find ./feeds/luci/collections/ -type f -name "Makefile" -exec sed -i "/attendedsysupgrade/d" {} +
#修改默认主题
find ./feeds/luci/collections/ -type f -name "Makefile" -exec sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" {} +
#修改immortalwrt.lan关联IP
find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js" -exec sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" {} +
#添加编译日期标识
find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js" -exec sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_CI-$WRT_DATE')/g" {} +
#修改默认WIFI名
#sed -i "s/\.ssid=.*/\.ssid=$WRT_SSID/g" $(find ./package/kernel/mac80211/ ./package/network/config/ -type f -name "mac80211.*")

#修改默认WIFI名&密码
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
ROUTER_TOOL="./package/emortal/luci-app-router-tool/root/etc/config/router-tool"
for file in "$ROUTER_TOOL" "$WIFI_UC"; do
	[ -f "$file" ] && sed -i "s/ssid '.*'/ssid '$WRT_SSID'/g; s/key '.*'/key '$WRT_PWD'/g" "$file"
done

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_HOSTNAME'/g" $CFG_FILE

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
  echo "手动调整的插件$WRT_PACKAGE".
	echo $WRT_PACKAGE | tr ' ' '\n' | while read line; do echo "处理插件 $line"; echo "CONFIG_PACKAGE_$line" >> ./.config; done
fi

#手动调整的配置项
if [ -n "$WRT_CONFIG" ]; then
  echo "手动调整的配置项$WRT_CONFIG".
  echo $WRT_CONFIG | tr ' ' '\n' | while read line; do echo "添加配置项 $line"; echo "$line" >> ./.config; done
fi

echo "init settings end."
#exit 0
