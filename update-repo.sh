#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR/repo"
CONFIG_DIR="$REPO_DIR/assets/repo"
CONFIG_FILE="$CONFIG_DIR/repo.conf"
REPO_URL="https://repo.adriancastro.dev"

mkdir -p "$REPO_DIR/debs"

APT_FTPARCHIVE="apt-ftparchive"

key_id=""
if [[ -n "${GPG_KEY_ID:-}" ]]; then
    key_id="$GPG_KEY_ID"
fi

process_packages() {
    while read -r line; do
        echo "$line"
        if [[ -z "$line" ]]; then
            package_id=$(grep "Package:" -B 10 | tail -n 1 | cut -d' ' -f2)
            echo "Depiction: $REPO_URL/depictions/web/?p=$package_id"
            echo "SileoDepiction: $REPO_URL/depictions/native/$package_id/depiction.json"
        fi
    done
}

cd "$REPO_DIR"

if [[ "$OSTYPE" == "linux"* ]]; then
    # Linux setup
    if ! command -v apt-ftparchive &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y apt-utils
    fi

elif [[ "$(uname)" == "Darwin" ]] && [[ "$(uname -p)" == "i386" ]]; then
    # macOS setup
    if ! command -v brew &> /dev/null; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    fi
    brew list --verbose wget || brew install wget
    brew list --verbose xz || brew install xz
    brew list --verbose zstd || brew install zstd
    
    if [ ! -f "./apt-ftparchive" ]; then
        wget -q -nc https://apt.procurs.us/apt-ftparchive
        chmod 751 ./apt-ftparchive
    fi
    APT_FTPARCHIVE="./apt-ftparchive"
fi

rm -f Packages Packages.{xz,gz,bz2,zst} Release{,.gpg} InRelease

# Generate Packages file
$APT_FTPARCHIVE packages ./debs | process_packages > Packages

# Compress Packages file
gzip -c9 Packages > Packages.gz
xz -c9 Packages > Packages.xz
zstd -c19 Packages > Packages.zst
bzip2 -c9 Packages > Packages.bz2

# Generate Contents file
$APT_FTPARCHIVE contents ./debs > Contents-iphoneos-arm

# Compress Contents file
bzip2 -c9 Contents-iphoneos-arm > Contents-iphoneos-arm.bz2
xz -c9 Contents-iphoneos-arm > Contents-iphoneos-arm.xz
xz -5fkev --format=lzma Contents-iphoneos-arm > Contents-iphoneos-arm.lzma
lz4 -c9 Contents-iphoneos-arm > Contents-iphoneos-arm.lz4
gzip -c9 Contents-iphoneos-arm > Contents-iphoneos-arm.gz
zstd -c19 Contents-iphoneos-arm > Contents-iphoneos-arm.zst

# Generate Release file
$APT_FTPARCHIVE release -c "$CONFIG_FILE" . > Release

# Sign Release file if key is available
if [[ -n "$key_id" ]]; then
    gpg -abs -u "$key_id" -o Release.gpg Release
    gpg -abs -u "$key_id" --clearsign -o InRelease Release
fi

echo "Repository Updated!"
