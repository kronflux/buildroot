AA_PROXY_RS_VERSION = main
AA_PROXY_RS_SITE = https://github.com/aa-proxy/aa-proxy-rs.git
AA_PROXY_RS_SITE_METHOD = git

# obtain git hashes for aa-proxy-rs and buildroot
BUILDROOT_DIR = $(realpath $(TOPDIR)/..)
BUILDROOT_COMMIT = $(shell git config --global --add safe.directory $(BUILDROOT_DIR) && git -C $(BUILDROOT_DIR) rev-parse HEAD)

# When using _OVERRIDE_SRCDIR (local build), read git hash from the local repo;
# otherwise use the downloaded git clone in DL_DIR.
ifneq ($(AA_PROXY_RS_OVERRIDE_SRCDIR),)
AA_PROXY_RS_GIT_DIR = $(AA_PROXY_RS_OVERRIDE_SRCDIR)
else
AA_PROXY_RS_GIT_DIR = $(realpath $(DL_DIR)/aa-proxy-rs/git)
endif

AA_PROXY_RS_COMMIT = $(shell git config --global --add safe.directory $(AA_PROXY_RS_GIT_DIR) && git -C $(AA_PROXY_RS_GIT_DIR) rev-parse HEAD)

# When using _OVERRIDE_SRCDIR, the download step (which vendors cargo deps)
# is skipped. Re-extract the vendor tarball on top of the rsynced source.
ifneq ($(AA_PROXY_RS_OVERRIDE_SRCDIR),)
define AA_PROXY_RS_VENDOR_DEPS
    $(TAR) -xf $(DL_DIR)/aa-proxy-rs/$(notdir $(wildcard $(DL_DIR)/aa-proxy-rs/*cargo*.tar.gz)) \
        --wildcards --strip-components=1 -C $(@D) '*/.cargo' '*/VENDOR'
endef
AA_PROXY_RS_POST_RSYNC_HOOKS += AA_PROXY_RS_VENDOR_DEPS
endif

define AA_PROXY_RS_INSTALL_TARGET_CMDS
    $(INSTALL) -D -m 0755 $(@D)/target/$(RUSTC_TARGET_NAME)/release/aa-proxy-rs $(TARGET_DIR)/usr/bin
    $(INSTALL) -D -m 0644 $(@D)/target/release/config.toml $(TARGET_DIR)/etc/aa-proxy-rs/config.toml
    $(INSTALL) -D -m 0755 $(@D)/contrib/S93aa-proxy-rs $(TARGET_DIR)/etc/init.d
endef

# pass git hashes as env variables
AA_PROXY_RS_CARGO_ENV = \
    AA_PROXY_COMMIT="$(AA_PROXY_RS_COMMIT)" \
    BUILDROOT_COMMIT="$(BUILDROOT_COMMIT)" \
    AA_PROXY_BOARD="$(notdir $(patsubst %/,%,$(CONFIG_DIR)))"

# use own toolchain only for RISC-V builds (milkv-duos)
ifeq ($(findstring milkv-duos,$(CONFIG_DIR)),milkv-duos)
# Add our own toolchain to path
AA_PROXY_RS_CARGO_ENV += PATH=/app/buildroot/output/milkv-duos/build/riscv/bin:$(BR_PATH)
endif

# disable wasm-scripting on armv6 (wasmtime doesn't support it)
ifeq ($(RUSTC_TARGET_NAME),arm-unknown-linux-gnueabihf)
AA_PROXY_RS_CARGO_BUILD_OPTS += --no-default-features
endif

# default config file generator
define AA_PROXY_RS_GENERATE_CONFIG
    cd $(@D) && env PATH=$${PATH}:$(HOST_DIR)/bin cargo run --release --bin generate_config
endef
AA_PROXY_RS_POST_BUILD_HOOKS += AA_PROXY_RS_GENERATE_CONFIG

$(eval $(cargo-package))
