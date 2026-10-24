#!/bin/sh
set -eu

workspace=${ZT_CORE_WORKSPACE:-$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)}
core_version=$(tr -d '\r\n' < "$workspace/CORE_VERSION")
core_commit=$(tr -d '\r\n' < "$workspace/CORE_COMMIT")
printf '%s\n' "$core_version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || {
  echo 'Invalid CORE_VERSION' >&2; exit 1;
}
printf '%s\n' "$core_commit" | grep -Eq '^[0-9a-f]{40}$' || {
  echo 'Invalid CORE_COMMIT' >&2; exit 1;
}

cc=${ZT_CC:-aarch64-linux-gnu-gcc}
cxx=${ZT_CXX:-aarch64-linux-gnu-g++}
strip_tool=${ZT_STRIP:-aarch64-linux-gnu-strip}
toolchain_info=$(
    "$cc" --version || exit 1
    "$cxx" --version || exit 1
    "$cc" -dumpmachine || exit 1
    "$strip_tool" --version || exit 1
    printf 'CFLAGS=%s\nCXXFLAGS=%s\nLDFLAGS=%s\n' "${CFLAGS:-}" "${CXXFLAGS:-}" "${LDFLAGS:-}"
    for library in libc.a libstdc++.a libgcc.a; do
      library_path=$("$cxx" -print-file-name="$library") || exit 1
      [ -f "$library_path" ] || exit 1
      sha256sum "$library_path" || exit 1
    done
)
toolchain_id=$(printf '%s\n' "$toolchain_info" | sha256sum | cut -d ' ' -f1)
script_sha=$(sha256sum "$0" | cut -d ' ' -f1)
cache_key=$(printf '%s\n' "$core_version" "$core_commit" "$toolchain_id" "$script_sha" | sha256sum | cut -d ' ' -f1)
cache_key="zt-linux-aarch64-$cache_key"
if [ "${1:-}" = --cache-key ]; then
  echo "$cache_key"
  exit 0
fi
if [ "$#" -ne 0 ]; then
  echo "Usage: $0 [--cache-key]" >&2; exit 2
fi

cache_dir="$workspace/.cache/core/$cache_key"
mkdir -p "$cache_dir"
verify_binary() {
  file -b "$1" | grep -Eq 'ELF 64-bit.*ARM aarch64.*statically linked'
}
if [ -f "$cache_dir/zerotier-one" ] && [ -f "$cache_dir/zerotier-one.sha256" ] && \
    (cd "$cache_dir" && sha256sum -c zerotier-one.sha256) && verify_binary "$cache_dir/zerotier-one"; then
  cp "$cache_dir/zerotier-one" "$workspace/zerotier-one"
  chmod 755 "$workspace/zerotier-one"
  echo "Reused verified ZeroTier ${core_version} ARM64 core"
  exit 0
fi

build_dir=$(mktemp -d)
cleanup() { rm -rf "$build_dir"; }
trap cleanup 0 1 2 15
git init --quiet "$build_dir/source"
git -C "$build_dir/source" remote add origin https://github.com/zerotier/ZeroTierOne.git
git -C "$build_dir/source" fetch --depth 1 origin "refs/tags/$core_version"
git -C "$build_dir/source" checkout --quiet --detach FETCH_HEAD
actual_commit=$(git -C "$build_dir/source" rev-parse HEAD)
if [ "$actual_commit" != "$core_commit" ]; then
  echo "ZeroTier source commit mismatch: expected $core_commit, got $actual_commit" >&2
  exit 1
fi

# Explicitly disable unused SSO/controller targets rather than editing upstream
# makefiles. This also supplies the empty zeroidc target in embedded builds.
make -C "$build_dir/source" -j"${ZT_BUILD_JOBS:-$(nproc)}" \
  CC="$cc" CXX="$cxx" ZT_STATIC=1 ZT_EMBEDDED=1 \
  ZT_SSO_SUPPORTED=0 ZT_CONTROLLER=0 one
"$strip_tool" "$build_dir/source/zerotier-one"
verify_binary "$build_dir/source/zerotier-one" || {
  echo 'Unexpected ZeroTier core architecture or linkage' >&2; exit 1;
}
cp "$build_dir/source/zerotier-one" "$cache_dir/zerotier-one"
chmod 755 "$cache_dir/zerotier-one"
(cd "$cache_dir" && sha256sum zerotier-one > zerotier-one.sha256)
cp "$cache_dir/zerotier-one" "$workspace/zerotier-one"
chmod 755 "$workspace/zerotier-one"
echo "Built verified ZeroTier ${core_version} ARM64 core at ${core_commit}"
