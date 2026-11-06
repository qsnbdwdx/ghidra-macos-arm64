# Building the Ghidra macOS arm64 decompiler from source

This is the recipe used to produce the binaries in `bin/`. It takes roughly **5–10 minutes** on an M-series Mac.

**Prerequisites**

| Tool | Notes |
|---|---|
| Xcode Command Line Tools | `xcode-select --install`. Full Xcode is **not** required. |
| JDK 21+ | Needed to *run* Ghidra; the C++ build itself only needs clang. |
| git | For the sparse checkout. |

Verify the toolchain:

```bash
cc --version          # Apple clang ...
make --version
xcrun --show-sdk-path # prints an SDK path
```

---

## 1. Sparse-checkout only what you need

The full Ghidra repo is large. You only need the decompiler sources, so clone sparsely:

```bash
git clone --depth 1 --branch Ghidra_12.1.4_build \
  --filter=blob:none --sparse \
  https://github.com/NationalSecurityAgency/ghidra.git ghidra-src

cd ghidra-src
git sparse-checkout set Ghidra/Features/Decompiler
```

That pulls ~20 MB instead of the whole tree.

```bash
cd Ghidra/Features/Decompiler/src/decompile/cpp
```

---

## 2. Trap #1 — do not use `make decompile`

The obvious target builds the **standalone command-line** decompiler, which links against BFD:

```
./loadimage_bfd.hh:37:10: fatal error: 'bfd.h' file not found
```

Ghidra does not need that binary. The two targets Ghidra actually loads are:

```bash
make ghidra_opt      # → decompile
make sleigh_opt      # → sleigh
```

Neither needs binutils.

---

## 3. Trap #2 — the Makefile hardcodes x86_64

In the upstream `Makefile`, the Darwin branch reads:

```makefile
ifeq ($(OS),Darwin)
  MAKE_STATIC=
  ARCH_TYPE=-arch x86_64
  ADDITIONAL_FLAGS=-mmacosx-version-min=10.6 -w
  OSDIR=mac_x86_64
endif
```

On Apple Silicon this produces an **Intel** binary and installs it under `mac_x86_64/` — where Ghidra on arm64 will never look.

Patch it:

```makefile
ifeq ($(OS),Darwin)
  MAKE_STATIC=
  ARCH_TYPE=-arch arm64
  ADDITIONAL_FLAGS=-mmacosx-version-min=11.0 -w
  OSDIR=mac_arm_64
endif
```

Note `-mmacosx-version-min=10.6` is invalid for arm64; use `11.0`.

Apply it in one shot:

```bash
cp Makefile Makefile.bak
python3 - <<'PY'
p = 'Makefile'
s = open(p).read()
old = """ifeq ($(OS),Darwin)
  MAKE_STATIC=
  ARCH_TYPE=-arch x86_64
  ADDITIONAL_FLAGS=-mmacosx-version-min=10.6 -w
  OSDIR=mac_x86_64
endif"""
new = """ifeq ($(OS),Darwin)
  MAKE_STATIC=
  ARCH_TYPE=-arch arm64
  ADDITIONAL_FLAGS=-mmacosx-version-min=11.0 -w
  OSDIR=mac_arm_64
endif"""
assert old in s, "Darwin block not found — upstream Makefile changed"
open(p, 'w').write(s.replace(old, new))
print("patched")
PY
```

---

## 4. Build

```bash
make ghidra_opt -j"$(sysctl -n hw.ncpu)"
make sleigh_opt -j"$(sysctl -n hw.ncpu)"
```

Confirm the output architecture:

```bash
file ghidra_opt sleigh_opt
# ghidra_opt: Mach-O 64-bit executable arm64
# sleigh_opt: Mach-O 64-bit executable arm64
```

---

## 5. Install

The compiled artifacts have different names than Ghidra expects, so rename on install:

```bash
GHIDRA=/Applications/ghidra_12.1.4_PUBLIC
DEST="$GHIDRA/Ghidra/Features/Decompiler/os/mac_arm_64"

mkdir -p "$DEST"
cp ghidra_opt "$DEST/decompile"
cp sleigh_opt "$DEST/sleigh"
chmod +x "$DEST/decompile" "$DEST/sleigh"
```

---

## 6. Verify end to end

A headless import proves the decompiler engine is actually invoked (the analysis runs `DecompilerSwitchAnalyzer`, which shells out to `decompile`):

```bash
export JAVA_HOME=/path/to/jdk-21/Contents/Home
export GHIDRA_INSTALL_DIR="$GHIDRA"

"$GHIDRA/support/analyzeHeadless" /tmp/ghidra-test proj1 -import /bin/echo
```

Look for:

```
INFO  REPORT: Analysis succeeded for file: file:///bin/echo
```

If `decompile` were missing or the wrong architecture, analysis fails here.

For pseudocode output, add a post-script that calls `DecompInterface` — see `scripts/DecompileProbe.java` in this repo:

```bash
"$GHIDRA/support/analyzeHeadless" /tmp/ghidra-test proj1 \
  -process echo -noanalysis \
  -scriptPath "$(pwd)/scripts" \
  -postScript DecompileProbe.java
```

---

## Why 12.1.x only

Ghidra's decompiler binary exchanges a private protocol with the Java side, and the processor-spec (`sleigh`) format plus internal ABI are tied to the release. `ghidra_opt` built from 12.1.4 sources is not guaranteed to load under 12.0 or 12.2.

If you need a different version, rebuild from that tag rather than reusing these binaries.
