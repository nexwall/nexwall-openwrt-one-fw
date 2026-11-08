# Boards, profiles and what each image contains

| Item | State |
|---|---|
| Kernel, drivers, Wi-Fi firmware | from the upstream OpenWrt device profile of each board (kernel 6.12) |
| Wi-Fi access point in the LAN zone | `config/wireless.conf` (hostapd, netifd wireless handler); default SSID and password are set in the wizard |
| WAN fallback | `ns-wan-fallback`: static 192.168.0.2/24, gateway 192.168.0.1, DNS 192.168.0.1 and 8.8.8.8 when DHCP gives no lease |
| Web proxy | Squid with SSL bump and ICAP (`config/squid.conf`) |
| Traffic classification | `netifyd`; its proprietary plugins are enabled per architecture once a build for `aarch64` is pinned |
| Antivirus engines | off in the lite profile (`NEXWALL_WEBPROTECTION_AV=n`); to be enabled per board after RAM measurements |
| Defconfig drop check | `config/targets/mediatek_filogic.expected-drops`: a requested symbol that `make defconfig` drops and is not listed stops the build |

The profile is `config/profiles/openwrt_one.conf` (`PROFILE=openwrt_one`, the default).
