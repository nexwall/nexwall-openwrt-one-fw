#
# Copyright (C) 2026 Nexwall
#
# This is free software, licensed under the GNU General Public License v2.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=nexwall-license
PKG_VERSION:=1.1.0
PKG_RELEASE:=5

PKG_MAINTAINER:=Nexwall
PKG_LICENSE:=GPL-2.0-only

# The license core (licensing decisions, check-in with the license server, enforcement, self-update) is a vendor
# binary: built from a private repository and published, signed, to the Nexwall vendor feed. This recipe does not
# contain it; it downloads one pinned version at build time and checks its SHA-256, so the public build is
# reproducible and a changed file on the feed is refused. Without it (option off, other architecture, feed not
# reachable by the builder) the image is a community build: no licensing logic is shipped and the unit runs with
# the limited feature set. See nexwall-internal/msp/LICENSE_PROTECTION_ARCHITECTURE.md.
# Versions differ per architecture: x86_64 follows the main product; the ARM builds (aarch64, arm) are pinned to the
# last core built for them. Publish an ARM build of a newer core, then bump its pin here.
VENDOR_CORE_VERSION_x86_64:=1.9.0
VENDOR_CORE_VERSION_aarch64:=1.7.1
VENDOR_CORE_VERSION_arm:=1.7.1
VENDOR_CORE_VERSION:=$(VENDOR_CORE_VERSION_$(ARCH))
VENDOR_CORE_SHA256_x86_64:=3dcaaea51b06fa3f13a1cc51df9ce4ce0b8b49fb8b4cffb423f1502fedb59733
VENDOR_CORE_SHA256_aarch64:=ebce79bc340f6def8d2120670849fed5533399452f99524cb66a084a1ab43175
VENDOR_CORE_SHA256_arm:=dcbb29ffc10b0164cf7037e019a88eeff99bea86b30e40d289bf5c9e7238332c
VENDOR_FEED:=https://updates.nexwall.com.br/vendor/stable

# One pinned build per architecture. An option that is on for an architecture without a pin stops the build:
# a silent fallback would ship an unlicensed community build.
ifeq ($(CONFIG_NEXWALL_LICENSE_VENDOR_CORE),y)
ifeq ($(VENDOR_CORE_SHA256_$(ARCH)),)
$(error nexwall-license: no vendor binary is pinned for architecture $(ARCH); set NEXWALL_LICENSE_VENDOR_CORE=n for an explicit community build)
endif
PKG_SOURCE:=nexwall-license-core_$(VENDOR_CORE_VERSION)_$(ARCH).tar.gz
PKG_SOURCE_URL:=$(VENDOR_FEED)/$(ARCH)
PKG_HASH:=$(VENDOR_CORE_SHA256_$(ARCH))
endif

include $(INCLUDE_DIR)/package.mk

define Package/nexwall-license
	SECTION:=base
	CATEGORY:=Nexwall
	TITLE:=Nexwall license
	DEPENDS:=+ca-bundle
	PKGARCH:=$(if $(CONFIG_NEXWALL_LICENSE_VENDOR_CORE),$(ARCH_PACKAGES),all)
endef

define Package/nexwall-license/config
	config NEXWALL_LICENSE_VENDOR_CORE
		bool "Include the Nexwall license core (vendor binary from the Nexwall vendor feed)"
		depends on PACKAGE_nexwall-license
		default y
		help
		  Without it the image is a community build: no licensing logic is included and the
		  unit runs with the limited feature set.
endef

define Package/nexwall-license/description
	Starts the Nexwall license core when it is installed (it registers this firewall with the license
	server, keeps the signed license current and applies the entitlements) and keeps the unit's license
	identity across upgrades.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	if [ -n "$(PKG_SOURCE)" ]; then tar -C $(PKG_BUILD_DIR) -xzf $(DL_DIR)/$(PKG_SOURCE); fi
endef

define Build/Compile
endef

define Package/nexwall-license/install
	if [ -f $(PKG_BUILD_DIR)/nexwall-licensed ]; then \
		$(INSTALL_DIR) $(1)/usr/sbin; \
		$(INSTALL_BIN) $(PKG_BUILD_DIR)/nexwall-licensed $(1)/usr/sbin/nexwall-licensed; \
		for n in licensectl nexwall-license-register nexwall-license-enforce nexwall-serial; do \
			$(LN) nexwall-licensed $(1)/usr/sbin/$$$$n; \
		done; \
	fi

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/nexwall-license.init $(1)/etc/init.d/nexwall-license

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/nexwall-license.config $(1)/etc/config/nexwall-license

	# kept across image upgrades: without hwid/serial/device_token/device.key the unit would re-register as a NEW
	# device on every upgrade (exhausting the customer's firewall_limit), and an assigned unit that lost its device
	# key is refused by the server until an administrator clears it
	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	$(INSTALL_CONF) ./files/nexwall-license.keep $(1)/lib/upgrade/keep.d/nexwall-license

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/nexwall-license-cron $(1)/etc/uci-defaults/99-nexwall-license-cron
endef

$(eval $(call BuildPackage,nexwall-license))
