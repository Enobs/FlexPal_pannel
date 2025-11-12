# 1️⃣ 确保无线已启用
rfkill unblock all
nmcli radio wifi on

# 2️⃣ 停掉旧连接，清理同名配置
nmcli connection down FlexPAL_Hotspot 2>/dev/null || true
nmcli connection delete FlexPAL_Hotspot 2>/dev/null || true

# 3️⃣ 创建新的热点配置（名称 & SSID 都叫 FlexPAL_Hotspot）
nmcli connection add type wifi ifname wlxa8637d311d40 con-name FlexPAL_Hotspot autoconnect no ssid FlexPAL_Hotspot

# 4️⃣ 设置热点参数
nmcli connection modify FlexPAL_Hotspot 802-11-wireless.mode ap
nmcli connection modify FlexPAL_Hotspot 802-11-wireless.band bg
nmcli connection modify FlexPAL_Hotspot 802-11-wireless.channel 6
nmcli connection modify FlexPAL_Hotspot 802-11-wireless.security wpa-psk
nmcli connection modify FlexPAL_Hotspot wifi-sec.key-mgmt wpa-psk
nmcli connection modify FlexPAL_Hotspot wifi-sec.psk "12345678"

# 5️⃣ 固定 IP 网段为 192.168.137.0/24（广播地址 192.168.137.255）
nmcli connection modify FlexPAL_Hotspot ipv4.addresses 192.168.137.1/24
nmcli connection modify FlexPAL_Hotspot ipv4.method shared
nmcli connection modify FlexPAL_Hotspot ipv6.method ignore
nmcli connection modify FlexPAL_Hotspot 802-11-wireless.ap-isolation 0 || true

# 6️⃣ 启动热点
nmcli connection up FlexPAL_Hotspot

# 7️⃣ 显示结果
echo
echo "✅ Hotspot 已启动"
ip -4 addr show wlxa8637d311d40 | grep inet
echo "SSID: FlexPAL_Hotspot"
echo "密码: 12345678"
echo "子网: 192.168.137.0/24"
echo "广播: 192.168.137.255"
