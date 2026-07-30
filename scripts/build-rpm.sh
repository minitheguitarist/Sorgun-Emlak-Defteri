#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bundle_dir="$repo_dir/build/linux/x64/release/bundle"
top_dir="$repo_dir/build/rpmbuild"

if [[ ! -x "$bundle_dir/sorgun_emlak_defteri" ]]; then
  echo "Linux release bundle bulunamadı. Önce flutter build linux --release çalıştırın." >&2
  exit 1
fi

mkdir -p \
  "$top_dir/BUILD" \
  "$top_dir/BUILDROOT" \
  "$top_dir/RPMS" \
  "$top_dir/SOURCES" \
  "$top_dir/SPECS" \
  "$top_dir/SRPMS"

rpmbuild -bb "$repo_dir/packaging/rpm/sorgun-emlak-defteri.spec" \
  --define "_topdir $top_dir" \
  --define "repo_dir $repo_dir" \
  --define "bundle_dir $bundle_dir"

find "$top_dir/RPMS" -type f -name '*.rpm' -print
