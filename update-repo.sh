#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR/repo"
CONFIG_DIR="$REPO_DIR/assets/repo"
CONFIG_FILE="$CONFIG_DIR/repo.conf"
REPO_URL="https://repo.adriancastro.dev"

key_id=""

if [[ -n "${GPG_KEY_ID:-}" ]]; then
    key_id="$GPG_KEY_ID"
    echo "Using GPG key ID from environment: $key_id"
fi

update_repo() {
    cd "$REPO_DIR" || exit
    rm -f Packages* Contents-iphoneos-arm* Release* 2> /dev/null

    /usr/bin/apt-ftparchive packages ./debs > Packages.tmp

    while IFS= read -r line; do
        if [[ $line =~ ^Package:\ (.*)$ ]]; then
            pkg_id="${BASH_REMATCH[1]}"
            
            has_depiction=$(grep -A 10 "^Package: $pkg_id$" Packages.tmp | grep -c "^Depiction:" || true)
            has_sileo=$(grep -A 10 "^Package: $pkg_id$" Packages.tmp | grep -c "^SileoDepiction:" || true)
            
            if [[ $has_depiction -eq 0 && -d "depictions/web/$pkg_id" ]]; then
                echo "Depiction: $REPO_URL/depictions/web/?p=$pkg_id" >> Packages.tmp
            fi
            if [[ $has_sileo -eq 0 && -f "depictions/native/$pkg_id/depiction.json" ]]; then
                echo "SileoDepiction: $REPO_URL/depictions/native/$pkg_id/depiction.json" >> Packages.tmp
            fi
        fi
        echo "$line" >> Packages
    done < Packages.tmp
    rm Packages.tmp

    gzip -c9 Packages > Packages.gz
    xz -c9 Packages > Packages.xz
    zstd -c19 Packages > Packages.zst
    bzip2 -c9 Packages > Packages.bz2

    /usr/bin/apt-ftparchive contents ./debs > Contents-iphoneos-arm
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
