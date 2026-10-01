# The mirrored WebRTC framework

This branch exists so that [`rpromas/rysysv2`](https://github.com/rpromas/rysysv2)
can consume libwebrtc from its own copy. It is
[`stasel/WebRTC`](https://github.com/stasel/WebRTC) at the commit that released
M154, with three changes: `Package.swift` points at a release on this fork
instead of stasel's, and this note and `tools/mirror.sh` are added. The
framework itself is **not modified**: the zip on this fork's release is stasel's,
byte for byte, with stasel's checksum.

## Why a mirror at all

ADR-0020 chose upstream libwebrtc, prebuilt, unmodified, and re-hosted. The
re-hosting is the libsignal and GRDB shape: a dependency that runs on input an
attacker can reach is fetched once, verified, and built against from a copy we
control, so that a release deleted, re-tagged or replaced upstream does not move
under a build. stasel's binaries are built from the official source by a public
GitHub Actions workflow with no source modifications, which is why they were
chosen over building our own; building our own with
`tools_webrtc/ios/build_ios_libs.py`, outside the tree, is the fallback if stasel
stops keeping up (it skipped M142–M145). A fork with patches is foreclosed.

## What is in the release

`v154.0.0-rysys.1` carries `WebRTC-M154.xcframework.zip`, fetched and checked by
`tools/mirror.sh 154`:

| | |
| --- | --- |
| Chromium milestone | M154 |
| WebRTC branch | `branch-heads/8037` |
| WebRTC commit | `3a8b0c76e6b7bf0e72141047f82eb2c3f4862c8d` |
| From | `stasel/WebRTC` release `154.0.0` |
| Zip SHA-256 | `a2bcdda93578c82452ceb6e49d54a2746e1bcb4caf7c2fa601ffac8028b58c16` |
| Checksum published at | stasel's `Package.swift` at tag `154.0.0`, and the release notes |
| Slices | `ios-arm64`, `ios-x86_64_arm64-simulator`, `ios-x86_64_arm64-maccatalyst`, `macos-x86_64_arm64` |
| `ios-arm64` binary | 12.2 MB |

Both published checksums are on GitHub, as the zip is. Checking them catches a
corrupted or swapped asset, not a compromised publisher — there is no second
host, unlike libsignal's. What the mirror buys is that the bytes, once checked,
stop moving.

### What M154 carries that Rysys depends on

- The field trial **`WebRTC-EnableDtlsPqc`**, which adds **X25519MLKEM768** to the
  DTLS groups offered. Both strings are in the binary.
- **`RTCInitFieldTrialDictionary`**, the only public Objective-C route to field
  trials. It is marked deprecated ("Pass field trials when building
  PeerConnectionFactory", to be deleted after 2026-01-01) but nothing in the
  Objective-C API replaces it yet. If a bump removes it, `RysysCalls` stops
  compiling, which is the intended failure.
- **No stats field names the negotiated DTLS group.** The report carries
  `dtlsCipher`, `srtpCipher` and `tlsVersion`, not the group, so the runtime
  check ADR-0020 wants — end a call that did not negotiate the hybrid — cannot
  be written yet. The checklist below is the guard.

## Bumping

Follow Chromium milestones **at least quarterly**, and **immediately for a WebRTC
CVE**.

1. `tools/mirror.sh <milestone>`. It verifies the zip against both of stasel's
   published checksums and fails if the field trial, the hybrid group or
   `RTCInitFieldTrialDictionary` is gone.
2. Read the upstream log between the two branch heads for
   `WebRTC-EnableDtlsPqc`. The trial's listed expiry (2026-06-01) has passed:
   upstream will either make the hybrid the default or remove the switch. If it
   became the default, the trial is harmless and can later be dropped from
   `RysysCalls`; if it was removed without becoming the default, **stop** —
   that build has classical-only media, which ADR-0020 forecloses.
3. If the script reported a stats field for the DTLS group, open an issue in
   `rysysv2` for the runtime check.
4. Cut a `v<milestone>.0.0-rysys.1` release here carrying the zip, unchanged.
5. Move `milestone` and `checksum` in `Package.swift`, and update the table
   above.
6. In `rysysv2`, move `RysysCalls`' pinned revision, build, and run its tests:
   they create an offer through the engine and check its fingerprints and
   candidates.
7. **Verify X25519MLKEM768 is still offered and negotiated** on a real call
   between two devices running the new build, as `docs/device-verification.md`
   describes in `rysysv2`. DTLS 1.3's ServerHello is cleartext, so the group is
   readable from a capture: its `key_share` names group `0x11ec`. A string in the
   binary is not this check. Without it the bump does not ship.
