#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/assets/repo"
CONFIG_FILE="$CONFIG_DIR/repo.conf"
PACKAGES_DIR="$SCRIPT_DIR/debs"

key_id=""

if [[ -n "${GPG_KEY_ID:-}" ]]; then
    key_id="$GPG_KEY_ID"
    echo "Using GPG key ID from environment: $key_id"
fi

update_repo() {
    cd "$SCRIPT_DIR" || exit
    rm -f Packages* Contents-iphoneos-arm* Release* 2> /dev/null

    /usr/bin/apt-ftparchive packages "$PACKAGES_DIR" > Packages
    gzip -c9 Packages > Packages.gz
    xz -c9 Packages > Packages.xz
    zstd -c19 Packages > Packages.zst
    bzip2 -c9 Packages > Packages.bz2

    /usr/bin/apt-ftparchive contents "$PACKAGES_DIR" > Contents-iphoneos-arm
    bzip2 -c9 Contents-iphoneos-arm > Contents-iphoneos-arm.bz2
    xz -c9 Contents-iphoneos-arm > Contents-iphoneos-arm.xz
    xz -5fkev --format=lzma Contents-iphoneos-arm > Contents-iphoneos-arm.lzma
    lz4 -c9 Contents-iphoneos-arm > Contents-iphoneos-arm.lz4
    gzip -c9 Contents-iphoneos-arm > Contents-iphoneos-arm.gz
    zstd -c19 Contents-iphoneos-arm > Contents-iphoneos-arm.zst

    /usr/bin/apt-ftparchive release -c "$CONFIG_FILE" . > Release

    gpg -abs -u "$key_id" -o Release.gpg Release

    echo "Repository Updated and Signed!"
}

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file not found at $CONFIG_FILE"
    exit 1
fi

if [[ -z "$key_id" ]]; then
    echo "Error: No GPG key ID provided"
    exit 1
fi

update_repo
