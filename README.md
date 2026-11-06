# Ghidra macOS ARM64 Native Decompiler

**Prebuilt `decompile` + `sleigh` binaries for Ghidra 12.1.4 on Apple Silicon.**

Stop staring at `os/mac_arm_64/decompile does not exist`.

---

## The Problem

Starting with **Ghidra 12.1**, the official release no longer ships **any** macOS native components — neither `mac_x86_64` nor `mac_arm_64`.

If you run Ghidra 12.1.x on an M1/M2/M3/M4 Mac and open the Decompiler, you get:

```
ERROR os/mac_arm_64/decompile does not exist
(see GettingStarted.md, 'Building Native Components')
```

And `GettingStarted.md` points you at `support/buildNatives` — **which is not included in the release zip**.

Upstream status: [issue #9550](https://github.com/NationalSecurityAgency/ghidra/issues/9550) → **Closed as not planned**.

So you either build it yourself, or you don't decompile.

**This repo gives you the prebuilt binaries** — no Xcode, no Gradle, no 30-minute compile.

---

## Why these binaries are trustworthy

Built and functionally verified on an Apple Silicon Mac — not re-uploaded, not cross-compiled.

| Step | Result |
|---|---|
| Source | Ghidra tag `Ghidra_12.1.4_build` |
| Toolchain | Xcode CLT, Apple clang 17.0.0 |
| Build | `make ghidra_opt` + `make sleigh_opt`, clean |
| Architecture | `Mach-O 64-bit executable arm64` |
| **Functional proof** | Headless decompile of `/bin/echo` produced real C pseudocode (`PROBE_RESULT decompiled=3 failed=0`) |
| Downstream | REA's Ghidra health check: **8/8 green** |

**The time you save:** 10–30 minutes of compiling, plus two traps — `make decompile` dies on a missing `bfd.h`, and the Makefile hardcodes `-arch x86_64` so you silently get an Intel binary Ghidra will never load. Here it's ten seconds.

## Quick Install

```bash
git clone https://github.com/qsnbdwdx/ghidra-macos-arm64.git
cd ghidra-macos-arm64
./install.sh
```

The script auto-detects your Ghidra installation and copies the binaries into place.

Override the path if needed:

```bash
GHIDRA_INSTALL_DIR=/path/to/ghidra_12.1.4_PUBLIC ./install.sh
```

## Manual Install

1. Download Ghidra 12.1.4 and install **JDK 21 or newer**.
2. Copy the two binaries:

```bash
GHIDRA=/Applications/ghidra_12.1.4_PUBLIC

mkdir -p "$GHIDRA/Ghidra/Features/Decompiler/os/mac_arm_64"
cp bin/decompile "$GHIDRA/Ghidra/Features/Decompiler/os/mac_arm_64/decompile"
cp bin/sleigh    "$GHIDRA/Ghidra/Features/Decompiler/os/mac_arm_64/sleigh"
chmod +x "$GHIDRA/Ghidra/Features/Decompiler/os/mac_arm_64/"*
```

3. Restart Ghidra.

## Verify

```bash
file "$GHIDRA/Ghidra/Features/Decompiler/os/mac_arm_64/decompile"
# expected: Mach-O 64-bit executable arm64
```

Then open any binary in Ghidra → double-click a function → the decompiler window shows C pseudocode.

## Compatibility

| Component | Version |
|---|---|
| Ghidra | **12.1.4** (tested) |
| JDK | 21+ |
| Architecture | arm64 (Apple Silicon) |
| macOS | 11.0+ |

> **Why only 12.1.x?** The ELF/Mach-O loader and decompiler ABI change between minor releases. These binaries embed `ghidra_opt` built against the 12.1.4 source tree. Drop-in use on other major/minor versions is unsupported.

## Build It Yourself

If you'd rather build than trust a binary — good instinct. See [`BUILD.md`](BUILD.md) for the full recipe, including the two traps that cost hours:

1. **`make decompile` fails** — it pulls in BFD and dies on `bfd.h: No such file or directory`. Use `make ghidra_opt` and `make sleigh_opt` instead; neither needs binutils.
2. **The Makefile hardcodes x86_64** — the `Darwin` branch sets `ARCH_TYPE=-arch x86_64` and `OSDIR=mac_x86_64`. You must patch it for arm64.

## Checksums

```
SHA256 (decompile) = e31bc93586b13c7c4d3b705cce1d5ae761ca62e5bdd506ee3cdecbf9ee06fb54
SHA256 (sleigh)    = e669b6132d7358166542e3623a4e37ed2b00dbe4e14b00c9f2d2a682749b6036
```

Verify before installing:

```bash
shasum -a 256 -c SHA256SUMS
```

## Scope

These are **compiled artifacts of Ghidra's own source**, nothing more. No patches to Ghidra's behavior, no telemetry, no network access. The binaries are what `make ghidra_opt` / `make sleigh_opt` produce on an arm64 Mac.

## License

Ghidra is licensed under the **Apache License 2.0**. These binaries are derivative works of the Ghidra source tree and are distributed under the same license. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).

This project is **not affiliated with, endorsed by, or sponsored by** the National Security Agency or the Ghidra project. "Ghidra" is used descriptively.

## Credits

- Built against the [Ghidra](https://github.com/NationalSecurityAgency/ghidra) source tree at tag `Ghidra_12.1.4_build`.
- Build recipe cross-checked against the analysis in [ghidra#9550](https://github.com/NationalSecurityAgency/ghidra/issues/9550).
