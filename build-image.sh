#!/bin/bash

if [ -z "$1" ]; then
    echo "Error: No argument provided."
    echo "Usage: $0 <board/shell>"
    exit 1
fi

ARG=$1

if [ "$ARG" = "shell" ]; then
    echo "Entering interactive shell..."
    exec /bin/bash # Replace the current script process with a bash shell
else
    # make the configs dir writable
    sudo chmod a+w external/configs
    # merge defconfig for specified board
    external/scripts/defconfig_merger.sh ${ARG}

    BUILDROOT_DIR=/app/buildroot
    PATCH_DIR=/app/br-patches
    STAMP="$BUILDROOT_DIR/.stamp_patched"
    OUTPUT=${BUILDROOT_DIR}/output/${ARG}
    mkdir -p ${OUTPUT}

    # We need to download the host-tools for MilkV.
    # FIXME: consider using the upstream repository (https://github.com/sophgo/host-tools).
    # Downloading them into the target output and setting BR2_TOOLCHAIN_EXTERNAL_PATH
    # doesn't help, because Buildroot still resolves the path as /app/host-tools.
    # So the tools must be placed directly in the root /app directory.
    if [ "$ARG" = "milkv-duos" ]; then
        if [ ! -d /app/host-tools ]; then
            sudo git clone --depth=1 https://github.com/milkv-duo/host-tools.git /app/host-tools
            sudo rm -rf /app/host-tools/.git
        else
            echo "Host tools already exists"
        fi
    fi

    cd ${BUILDROOT_DIR}

    # Apply buildroot patches in order
    # Exit if already patched
    if [ -f "$STAMP" ]; then
        echo "Patch series already applied, skipping."
    else
        for p in $(ls "$PATCH_DIR"/*.patch | sort); do
            echo "Applying patch $p..."
            sudo patch -p1 < "$p"
        done
        # Create stamp file to mark patches applied
        sudo touch "$STAMP"
        echo "All patches applied successfully."
    fi

    # If local aa-proxy-rs source is mounted, use it via Buildroot _OVERRIDE_SRCDIR
    if [ -d /app/aa-proxy-rs ]; then
        echo "Local aa-proxy-rs source detected, using override."
        echo 'AA_PROXY_RS_OVERRIDE_SRCDIR = /app/aa-proxy-rs' > ${OUTPUT}/local.mk
    else
        # Remove stale local.mk to avoid pointing at a missing directory
        rm -f ${OUTPUT}/local.mk
    fi

    # If local canze-rs source is mounted, use it via Buildroot _OVERRIDE_SRCDIR
    if [ -d /app/canze-rs ]; then
        echo "Local canze-rs source detected, using override."
        echo 'CANZE_RS_OVERRIDE_SRCDIR = /app/canze-rs' >> ${OUTPUT}/local.mk
    fi

    make BR2_EXTERNAL=../external/ O=${OUTPUT} gen_${ARG}_defconfig
    cd ${OUTPUT}
    make -j$(nproc --all)
fi
