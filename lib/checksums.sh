#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — Pinned SHA256 Checksums
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================
#  POLICY: every external binary must be pinned here. If a hash
#  is "UNPINNED", the installer refuses to download the asset.
# ============================================================

FASTFETCH_VERSION="2.71.0"
CHECKSUM_FASTFETCH="6dc0b71c03e58f9f981a6b3c62b4fa3fb30b9d5ee9fa783302c91ea4c2a3600e"

BIBATA_VERSION="v2.0.7"
CHECKSUM_BIBATA="7d3495864e5bbef02f5e77de760b2905903b63c71495a78ef6306d19a3b556d8"

NERD_VERSION="v3.5.1"
CHECKSUM_JETBRAINSMONO="fab782a66f7d3019da64f6572db9fc5d3a4bcb19f9fa13e2d8a62e3693d6396e"

CLIPNOTIFY_COMMIT="25ba143c7da8ae0f196cb0db2797d30e6d04e15c"

VSCODIUM_GPG_FPR="1302DE60231889FE1EBACADC54678CF75A278D9C"
ONLYOFFICE_GPG_FPR="E09CA29F6E178040EF22B4098320CA65CB2DE8E5"

BLUETUI_VERSION="v0.8.2"
CHECKSUM_BLUETUI="b476ee473cb4f7a48cd75d440e991bedc835ff5ac704aac1f1992f8e826222fd"

_verify_checksum() {
    local file="$1" expected="$2" name="$3"
    local actual

    if [[ "$expected" == "UNPINNED" ]]; then
        warn "Checksum for '$name' is not pinned — refusing to install."
        warn "Pin it in lib/checksums.sh before running the installer."
        return 1
    fi

    if [[ ! -f "$file" ]]; then
        error "Checksum target '$file' does not exist."
    fi

    actual=$(sha256sum "$file" | cut -d' ' -f1)
    if [[ "$actual" != "$expected" ]]; then
        error "SHA256 mismatch for $name
  expected: $expected
  actual:   $actual
  file:     $file"
    fi
    return 0
}
