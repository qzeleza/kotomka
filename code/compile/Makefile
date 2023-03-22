# Файл манифеста для C
include $(TOPDIR)/rules.mk
PKG_NAME:=kotomka
PKG_VERSION:=0.0-alpha
PKG_RELEASE:=01
#PKG_RELEASE:=$(AUTORELEASE)
PKG_MAINTAINER:=AuthorName <author@email.ru>
PKG_LICENSE:=Freedom-2.0
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)
include $(INCLUDE_DIR)/package.mk
define Package/kotomka
	CATEGORY:=Keenetic
	SUBMENU:=Test_Sub_Menu
	TITLE:=Заголовок для тестового приложения для роутеров Keenetic.
	SECTION:=utils
	URL:=https://github.com/github_name/kotomka
	DEPENDS:=+libstdcpp +librt +libpthread
	PKGARCH:=mipsel-3.4
endef
define Package/kotomka/description
	Описание для тестового приложения для роутеров Keenetic 0.
Описание для тестового приложения для роутеров Keenetic 1.
Описание для тестового приложения для роутеров Keenetic 2.
Описание для тестового приложения для роутеров, Keenetic 3.
Описание для тестового приложения для роутеров Keenetic 4.
endef
define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	cp -rf /apps/kotomka/code/src/. $(PKG_BUILD_DIR)
	$(Build/Patch)
endef
define Build/Configure
endef
define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) CC="$(TARGET_CC)" CFLAGS="$(TARGET_CFLAGS) -Wall" LDFLAGS="$(TARGET_LDFLAGS)"
endef
define Package/kotomka/install
	$(INSTALL_DIR) $(1)/opt/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/kotomka $(1)/opt/bin/
endef
$(eval $(call BuildPackage,kotomka))
