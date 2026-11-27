#!/usr/bin/env bash
set -euo pipefail
: "${RELEASE_TAG:?Set RELEASE_TAG to the existing version tag}"
: "${GH_REPO:?Set GH_REPO to the target repository}"
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
notes="$project_dir/.github/releases/$RELEASE_TAG.md"
if [[ ! -s "$notes" ]]; then
    echo "Missing release notes: .github/releases/$RELEASE_TAG.md" >&2
    exit 1
fi
cd -- "${1:-dist}"
packages=(./*.AppImage ./*-setup-unsigned.exe ./*.dmg)
if [[ ${#packages[@]} -ne 3 ]]; then
    echo 'Expected exactly one package for each platform' >&2
    exit 1
fi
assets=()
for package in "${packages[@]}"; do
    if [[ ! -f "$package" || ! -f "$package.sha256" ]]; then
        echo "Missing package or checksum: $package" >&2
        exit 1
    fi
    sha256sum --check "$package.sha256"
    assets+=("$package" "$package.sha256")
done

if is_draft="$(gh release view "$RELEASE_TAG" --json isDraft --jq .isDraft 2>/dev/null)"; then
    if [[ "$is_draft" != true ]]; then
        echo "Refusing to modify published release $RELEASE_TAG" >&2
        exit 1
    fi
    gh release edit "$RELEASE_TAG" --notes-file "$notes"
else
    gh release create "$RELEASE_TAG" --verify-tag --draft \
        --title "Sori $RELEASE_TAG" --notes-file "$notes"
fi
gh release upload "$RELEASE_TAG" "${assets[@]}" --clobber
