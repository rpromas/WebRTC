#!/bin/bash
#
# Fetch stasel's prebuilt WebRTC XCFramework for one milestone, verify it, and
# report what a Rysys bump needs to know about it. Nothing is rebuilt and
# nothing is changed: the zip this leaves under WORK is the one that is
# uploaded, byte for byte, to this fork's release.
#
# Run from anywhere; everything happens under WORK.

set -euo pipefail

MILESTONE="${1:?usage: mirror.sh <milestone, e.g. 154>}"
VERSION="${MILESTONE}.0.0"
WORK="${WORK:-$PWD/build}"
ZIP="WebRTC-M${MILESTONE}.xcframework.zip"
URL="https://github.com/stasel/WebRTC/releases/download/${VERSION}/${ZIP}"

mkdir -p "$WORK"
cd "$WORK"

# --- fetch and verify -------------------------------------------------------
#
# stasel publishes the checksum in two places, the manifest at the release
# commit and the release notes. Both are on GitHub, as the zip is, so this
# catches a corrupted or swapped asset rather than a compromised account —
# there is no second host to check against. Both must agree.

if [ ! -f "$ZIP" ]; then
    curl -sSL -o "$ZIP" "$URL"
fi

from_manifest=$(gh api "repos/stasel/WebRTC/contents/Package.swift?ref=${VERSION}" \
    --jq .content | base64 -d | sed -n 's/.*checksum: "\([0-9a-f]*\)".*/\1/p')
from_notes=$(gh release view "$VERSION" --repo stasel/WebRTC --json body --jq .body \
    | sed -n 's/.*SHA 256 checksum: `\([0-9a-f]*\)`.*/\1/p')
actual=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)

echo "manifest checksum: $from_manifest"
echo "release checksum:  $from_notes"
echo "zip checksum:      $actual"
[ "$actual" = "$from_manifest" ] && [ "$actual" = "$from_notes" ] || {
    echo "checksum mismatch" >&2
    exit 1
}

# --- what Rysys depends on --------------------------------------------------
#
# A string in the binary is not proof the feature works — that is the
# negotiation check in ARTIFACT.md's checklist, run on a call. Its absence is
# proof it does not, and fails here before anyone builds against it.

rm -rf extracted && mkdir extracted
unzip -q "$ZIP" -d extracted
BINARY=extracted/WebRTC.xcframework/ios-arm64/WebRTC.framework/WebRTC
HEADERS=extracted/WebRTC.xcframework/ios-arm64/WebRTC.framework/Headers
# Read once into a file: `grep -q` closing a pipe early would fail the
# `strings` side of it under pipefail.
strings -a "$BINARY" > strings.txt

require() {
    if grep -qx "$1" strings.txt; then
        echo "present: $1"
    else
        echo "MISSING: $1 — $2" >&2
        exit 1
    fi
}
require "WebRTC-EnableDtlsPqc" "the field trial RysysCalls enables at factory creation"
require "X25519MLKEM768" "the hybrid group the trial adds"

if grep -q "RTCInitFieldTrialDictionary" "$HEADERS/RTCFieldTrials.h"; then
    echo "present: RTCInitFieldTrialDictionary"
else
    echo "MISSING: RTCInitFieldTrialDictionary — RysysCalls' only route to field trials" >&2
    exit 1
fi

# Whether the stats report names the negotiated DTLS group. ADR-0020 wants a
# runtime check that ends a non-hybrid call the day it does.
if grep -qiE '^(tlsGroup|dtlsGroup|sslGroup)' strings.txt; then
    echo "NOTE: the stats report may now expose the DTLS group — see ARTIFACT.md"
else
    echo "stats: no DTLS group field"
fi

echo
echo "upload: $WORK/$ZIP"
echo "checksum: $actual"
