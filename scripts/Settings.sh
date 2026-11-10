#!/bin/bash

#IP
WRT_IP=192.168.10.1
#hostname
WRT_HOSTNAME=OpenWrt
#ssid
WRT_SSID=OpenWrt
#wifi pwd
WRT_PWD=12345678
#theme可填 argon / aurora / vantage
WRT_THEME=aurora

# 移除luci-app-attendedsysupgrade软件包
find ./feeds/luci/collections/ -type f -name "Makefile" -exec sed -i "/attendedsysupgrade/d" {} +
# 修改 collections 依赖：只决定哪个主题包被编进固件，不决定开机显示哪个主题
find ./feeds/luci/collections/ -type f -name "Makefile" -exec sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" {} +
# 修改默认主题：真正生效的是 luci.main.mediaurlbase
THEME_CFG="./feeds/luci/modules/luci-base/root/etc/config/luci"
if [ -f "$THEME_CFG" ]; then
	sed -i "s|/luci-static/[a-zA-Z0-9_-]*|/luci-static/$WRT_THEME|g" "$THEME_CFG"
	grep -m1 "mediaurlbase" "$THEME_CFG" | sed 's/^/[Settings] /'
else
	echo "[Settings][WARN] 未找到 $THEME_CFG，跳过 mediaurlbase 修改"
fi
# 去掉各主题包 uci-defaults 里对 mediaurlbase 的争抢设置
find ./package/luci-theme-*/ ./feeds/luci/themes/luci-theme-*/ \
	-type f -path "*uci-defaults*" -exec sed -i '/set luci.main.mediaurlbase/d' {} + 2>/dev/null
# 用 99- 前缀的 uci-defaults 最后统一设定默认主题（首次开机执行）
mkdir -p ./files/etc/uci-defaults
cat > ./files/etc/uci-defaults/99-init-settings <<EOF
#!/bin/sh
uci set luci.main.mediaurlbase='/luci-static/$WRT_THEME'
uci commit luci
exit 0
EOF
chmod +x ./files/etc/uci-defaults/99-init-settings
echo "[Settings][OK] 默认主题设为 $WRT_THEME (files/etc/uci-defaults/99-init-settings)"
#修改immortalwrt.lan关联IP
find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js" -exec sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" {} +
#添加编译日期标识
find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js" -exec sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_CI-$WRT_DATE')/g" {} +
# 修改默认WIFI名&密码
# 6.12/25.12 源码用的是 ucode 版 mac80211.uc，格式为 set ${si}.ssid='...'
# （不是 /etc/config/wireless 的 option ssid '...'），且必须同时设置 encryption 密码才会生效
# 排除 netifd/wireless/ 下的协议脚本：它们只把 UCI 配置翻译成 hostapd 参数，不定义默认 SSID
WIFI_FILES=$(find ./package/kernel/mac80211/ ./package/network/config/ \
	-type f \( -name "mac80211.uc" -o -name "mac80211.sh" \) \
	! -path "*/netifd/*" 2>/dev/null)
if [ -z "$WIFI_FILES" ]; then
	echo "[Settings][WARN] 未找到 mac80211.uc / mac80211.sh，WiFi 默认配置未修改"
fi
for file in $WIFI_FILES; do
	[ -f "$file" ] || continue
	if grep -qF 'set ${si}.ssid=' "$file"; then
		sed -i \
			-e '/^set [$]{si}\.ssid=/s|.*|set ${si}.ssid='"'$WRT_SSID'"'|' \
			-e '/^set [$]{si}\.encryption=/s|.*|set ${si}.encryption='"'"'psk2'"'"'|' \
			-e '/^set [$]{si}\.key=/s|.*|set ${si}.key='"'$WRT_PWD'"'|' \
			-e '/^set [$]{si}\.disabled=/s|.*|set ${si}.disabled='"'"'0'"'"'|' \
			"$file"
		if grep -qF "ssid='$WRT_SSID'" "$file" && grep -qF "key='$WRT_PWD'" "$file"; then
			echo "[Settings][OK] WiFi 默认值已生效: SSID=$WRT_SSID / psk2 / $file"
		else
			echo "[Settings][WARN] WiFi 默认值校验未通过: $file"
		fi
	elif grep -qE 'set wireless\.default_.*\.ssid=' "$file"; then
		# 旧格式（23.05 及更早）：UCI 批处理模板，需同时写 SSID / 加密 / 密码 / 启用
		sed -i \
			-e "s/\.ssid=.*/\.ssid=$WRT_SSID/g" \
			-e "s|\(set wireless\.default_[^ ]*\.encryption=\).*|\1psk2\nset wireless.default_\${name}.key=$WRT_PWD|g" \
			-e "s/\.disabled=1/\.disabled=0/g" \
			"$file"
		if grep -qF ".ssid=$WRT_SSID" "$file" && grep -qF "key=$WRT_PWD" "$file"; then
			echo "[Settings][OK] WiFi 默认值已生效(旧格式): SSID=$WRT_SSID / psk2 / $file"
		else
			echo "[Settings][WARN] 旧格式 WiFi 默认值校验未通过: $file"
		fi
	else
		# 非默认配置生成器：只提示，不做任何 sed，避免误伤协议脚本
		echo "[Settings] 跳过（非默认配置生成器，未修改）: $file"
	fi
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
