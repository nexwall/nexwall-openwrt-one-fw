#!/usr/bin/env sh

#
# Copyright (C) 2025 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-2.0-only
#

set -e

# Snapshot current environment so it can be restored with highest precedence
_env_snapshot=$(export -p)

# Source versioned defaults first
set -o allexport
if [ -f build.conf.defaults ]; then
    echo "Loading build.conf.defaults..."
    . ./build.conf.defaults
fi

# Source local overrides second (can override defaults)
if [ -f build.conf ]; then
    echo "Loading build.conf (local overrides)..."
    . ./build.conf
fi
set +o allexport

# Re-apply original environment variables so they take final precedence over config files
eval "$_env_snapshot"

# Check required environment variables
OWRT_VERSION=${OWRT_VERSION:?Missing OWRT_VERSION environment variable}
NETHSECURITY_VERSION=${NETHSECURITY_VERSION:?Missing NETHSECURITY_VERSION environment variable}
REPO_CHANNEL=${REPO_CHANNEL:-dev}
TARGET=${TARGET:-mediatek_filogic}
# Board profile (config/profiles/<PROFILE>.conf): the image of one board. Same TARGET and volumes for every board.
PROFILE=${PROFILE:-bananapi_bpi-r3}
BUILD_SEMVER_SUFFIX=${BUILD_SEMVER_SUFFIX:-}
BUILD_VERBOSE=${BUILD_VERBOSE:-}
# Parallel make jobs inside the builder; empty means one per CPU. Lower it on small-RAM hosts.
MAKE_JOBS=${MAKE_JOBS:-}

# ARM fork: this build never shares a container, image or volume with the x86 build (nexwall/firewall-msp). The names
# below are the ones nexwall/internal-arm (lib-arm.sh) expects.
case "$TARGET" in
    x86*) echo "ERROR: $TARGET is an x86 target; x86 is built from the main repository" >&2; exit 1 ;;
esac
BUILDER_PREFIX=nexwall-bananapi
IMAGE_NAME="${BUILDER_PREFIX}-next"
CONTAINER_NAME="${BUILDER_PREFIX}-builder"
VOL_PREFIX="nexwall_bananapi_builder_${OWRT_VERSION}_${TARGET}"
# one build at a time on the server (CPU, ccache): only checks the x86 container, never touches it
for other in nethsecurity-builder nexwall-arm-builder nexwall-armv7-builder; do
    if podman ps --format '{{.Names}}' | grep -qx "$other"; then
        echo "ERROR: $other is running; not starting an Banana Pi build at the same time" >&2
        exit 1
    fi
done

if [ -f "./private-key.pem" ] && [ -f "./public-key.pem" ]; then
    APK_PRIV_KEY="$(cat ./private-key.pem)"
    APK_PUB_KEY="$(cat ./public-key.pem)"
fi


podman build \
    --force-rm \
    --layers \
    --file builder/Containerfile \
    --tag "$IMAGE_NAME" \
    --jobs 0 \
    --build-arg OWRT_VERSION="$OWRT_VERSION" \
    --build-arg REPO_CHANNEL="$REPO_CHANNEL" \
    --build-arg TARGET="$TARGET" \
    --build-arg PROFILE="$PROFILE" \
    --build-arg NETHSECURITY_VERSION="$NETHSECURITY_VERSION" \
    --build-arg BUILD_SEMVER_SUFFIX="$BUILD_SEMVER_SUFFIX" \
    .

# Source tarballs do not depend on the target: seed this target's download volume once from the x86 one (mounted
# read-only), so the ARM build does not have to fetch everything again.
SEED_SRC=""
for candidate in "nexwall_arm_builder_${OWRT_VERSION}_armsr_armv8_downloads" "nethsecurity_builder_${OWRT_VERSION}_downloads"; do
    if podman volume exists "$candidate"; then SEED_SRC="$candidate"; break; fi
done
if ! podman volume exists "${VOL_PREFIX}_downloads" && [ -n "$SEED_SRC" ]; then
    echo "Seeding ${VOL_PREFIX}_downloads from $SEED_SRC (read-only copy)..."
    podman volume create "${VOL_PREFIX}_downloads" >/dev/null
    podman run --rm --entrypoint cp \
        --volume "$SEED_SRC:/from:ro" \
        --volume "${VOL_PREFIX}_downloads:/home/buildbot/openwrt/download" \
        "$IMAGE_NAME" -a /from/. /home/buildbot/openwrt/download/ \
        || { podman volume rm -f "${VOL_PREFIX}_downloads" >/dev/null; echo "ERROR: seeding failed" >&2; exit 1; }
fi

# Vendor packages built locally from the private repositories (license core, web protection service, and later the
# traffic-engine plugins) are NOT published anywhere: put the tarballs in vendor-local/ (git-ignored) and they are
# copied into this target's download cache before every build. The recipes pin a SHA-256 per file, so a wrong or
# missing file stops the build; nothing is fetched from the vendor feed. Override the directory with VENDOR_LOCAL_DIR.
VENDOR_LOCAL_DIR="${VENDOR_LOCAL_DIR:-$PWD/vendor-local}"
if ls "$VENDOR_LOCAL_DIR"/*.tar.gz >/dev/null 2>&1; then
    podman volume exists "${VOL_PREFIX}_downloads" || podman volume create "${VOL_PREFIX}_downloads" >/dev/null
    echo "Copying local vendor packages into ${VOL_PREFIX}_downloads:"
    ls -1 "$VENDOR_LOCAL_DIR"/*.tar.gz | sed 's#.*/#  #'
    podman run --rm --entrypoint sh \
        --volume "$VENDOR_LOCAL_DIR:/vendor:ro" \
        --volume "${VOL_PREFIX}_downloads:/home/buildbot/openwrt/download" \
        "$IMAGE_NAME" -c 'cp -f /vendor/*.tar.gz /home/buildbot/openwrt/download/' \
        || { echo "ERROR: copying the local vendor packages failed" >&2; exit 1; }
else
    echo "No local vendor packages in $VENDOR_LOCAL_DIR: the recipes will try the vendor feed and stop if a pinned file is missing"
fi

set +e

status=0
podman run \
    --env APK_PRIV_KEY="$APK_PRIV_KEY" \
    --env APK_PUB_KEY="$APK_PUB_KEY" \
    --env BUILD_VERBOSE="$BUILD_VERBOSE" \
    --env MAKE_JOBS="$MAKE_JOBS" \
    --name "$CONTAINER_NAME" \
    --interactive \
    --tty \
    --replace \
    --volume "${VOL_PREFIX}_build:/home/buildbot/openwrt/build_dir" \
    --volume "${VOL_PREFIX}_staging:/home/buildbot/openwrt/staging_dir" \
    --volume "${VOL_PREFIX}_cache:/home/buildbot/openwrt/.ccache" \
    --volume "${VOL_PREFIX}_downloads:/home/buildbot/openwrt/download" \
    --volume "${VOL_PREFIX}_dl:/home/buildbot/openwrt/dl" \
    "$IMAGE_NAME" \
    "$@" || status=$?

if [ $status -eq 0 ]; then
    # Clean up previous builds
    rm -rf bin
    podman cp "$CONTAINER_NAME":/home/buildbot/openwrt/bin bin
fi

rm -rf build-logs
podman cp "$CONTAINER_NAME":/home/buildbot/openwrt/logs build-logs
podman stop "$CONTAINER_NAME"
podman rm "$CONTAINER_NAME"

exit $status
