CANZE_RS_VERSION = aa-proxy-obd
CANZE_RS_SITE = https://github.com/manio/canze-rs.git
CANZE_RS_SITE_METHOD = git

ifneq ($(CANZE_RS_OVERRIDE_SRCDIR),)
CANZE_RS_GIT_DIR = $(CANZE_RS_OVERRIDE_SRCDIR)
else
CANZE_RS_GIT_DIR = $(realpath $(DL_DIR)/canze-rs/git)
endif

ifneq ($(CANZE_RS_OVERRIDE_SRCDIR),)
define CANZE_RS_VENDOR_DEPS
    $(TAR) -xf $(DL_DIR)/canze-rs/$(notdir $(wildcard $(DL_DIR)/canze-rs/*cargo*.tar.gz)) \
        --wildcards --strip-components=1 -C $(@D) '*/.cargo' '*/VENDOR'
endef
CANZE_RS_POST_RSYNC_HOOKS += CANZE_RS_VENDOR_DEPS
endif

define CANZE_RS_INSTALL_TARGET_CMDS
    $(INSTALL) -D -m 0755 $(@D)/target/$(RUSTC_TARGET_NAME)/release/canze-rs $(TARGET_DIR)/usr/bin/canze-rs
endef

$(eval $(cargo-package))
