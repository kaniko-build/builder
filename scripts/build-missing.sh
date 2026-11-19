#!/usr/bin/env bash
# Build upstream kaniko releases newer than the last one published by this repo.
# Dry run by default; --dispatch triggers the "Build images" workflow.
set -euo pipefail
# Without it, a failed gh/docker call inside $(...) yields empty output instead of aborting.
shopt -s inherit_errexit

readonly BUILDER_REPO=kaniko-build/builder
readonly WORKFLOW=images.yml
readonly WORKFLOW_REF=build
readonly ALL_PLATFORMS=(linux/amd64 linux/arm64 linux/s390x linux/ppc64le)
readonly SEMVER_RE='^v[0-9]+\.[0-9]+\.[0-9]+$'
read -ra SOURCES <<<"${KANIKO_SOURCES:-osscontainertools/kaniko chainguard-forks/kaniko}"

die() { echo "error: $*" >&2; exit 1; }

usage() { echo "usage: $0 [--dispatch]" >&2; exit 2; }

# Image refs a target platform pulls; build-platform stages, scratch and stage aliases excluded.
external_refs() {
  awk 'toupper($1) == "FROM" {
    i = 2; bp = 0
    while ($i ~ /^--/) { if ($i ~ /BUILDPLATFORM/) bp = 1; i++ }
    ref = $i
    if (toupper($(i + 1)) == "AS") alias = tolower($(i + 2)); else alias = ""
    if (!(bp || ref == "scratch" || ref ~ /\$/ || (tolower(ref) in stages))) print ref
    if (alias != "") stages[alias] = 1
  }'
}

# JSON array of ALL_PLATFORMS offered by every base image of the tag's deploy/Dockerfile.
platforms_for() {
  local src=$1 tag=$2 dockerfile ref avail plats
  dockerfile=$(gh api "repos/$src/contents/deploy/Dockerfile?ref=$tag" --jq .content | base64 -d)
  plats=$(printf '%s\n' "${ALL_PLATFORMS[@]}")
  while read -r ref; do
    avail=$(docker buildx imagetools inspect --raw "$ref" | jq -r '.manifests[]?.platform | .os + "/" + .architecture')
    # grep exits 1 when nothing is left; an empty set is handled by the caller.
    plats=$(grep -Fxf <(printf '%s\n' "$avail") <<<"$plats" || true)
  done < <(external_refs <<<"$dockerfile")
  jq -cRn '[inputs | select(length > 0)]' <<<"$plats"
}

# Branch builds (<branch>-<sha>) are dropped: sort -V can rank them above every semver tag.
built_tags() {
  gh release list -R "$BUILDER_REPO" -L 1000 --json tagName |
    jq -r --arg p "$1/" --arg re "$SEMVER_RE" '.[].tagName | select(startswith($p)) | ltrimstr($p) | select(test($re))'
}

upstream_tags() {
  gh api --paginate "repos/$1/releases?per_page=100" \
    --jq '.[] | select((.draft or .prerelease) | not) | .tag_name' |
    { grep -E "$SEMVER_RE" || true; } # no stable release yet means nothing to build, not an error
}

# Every publish also moves :latest, so tags go oldest first and never below the last build.
pending_tags() {
  local src=$1 last
  last=$(built_tags "$src" | sort -V | tail -n1)
  [[ -n "$last" ]] || die "$src: no previous build, dispatch the first one by hand"
  { echo "$last"; upstream_tags "$src"; } | sort -uV | awk -v l="$last" 'f; $0 == l { f = 1 }'
}

dispatch_and_wait() {
  local src=$1 tag=$2 plats=$3 out run_id i
  out=$(gh workflow run "$WORKFLOW" -R "$BUILDER_REPO" --ref "$WORKFLOW_REF" \
    -f repository="$src" -f ref="$tag" -f platforms="$plats" 2>&1) || die "$src $tag: dispatch failed: $out"
  run_id=$(grep -oE 'actions/runs/[0-9]+' <<<"$out" | head -n1) || die "$src $tag: no run URL in: $out"
  run_id=${run_id##*/}
  echo "  run https://github.com/$BUILDER_REPO/actions/runs/$run_id"
  # The API answers 404 for a few seconds after the dispatch; the expected 404s are silenced.
  for i in {1..12}; do
    gh run view "$run_id" -R "$BUILDER_REPO" --json status >/dev/null 2>&1 && break
    ((i < 12)) || die "$src $tag: run $run_id never showed up"
    sleep 5
  done
  # A lost watch must stop everything: dispatching the next tag now would race on :latest.
  gh run watch "$run_id" -R "$BUILDER_REPO" --interval 60 >/dev/null || die "$src $tag: lost track of run $run_id"
  [[ "$(gh run view "$run_id" -R "$BUILDER_REPO" --json conclusion --jq .conclusion)" == success ]]
}

main() {
  local dispatch=false failed=0 cmd src tag plats in_flight pending
  local -a tags
  case "${1:-}" in
    "") ;;
    --dispatch) dispatch=true ;;
    *) usage ;;
  esac
  for cmd in gh jq docker base64; do
    command -v "$cmd" >/dev/null || die "missing command: $cmd"
  done

  in_flight=$(gh run list -R "$BUILDER_REPO" -w "$WORKFLOW" -L 50 --json status,displayTitle \
    --jq '.[] | select(.status != "completed") | .displayTitle')

  # ponytail: sources run one after another; a workflow matrix per source parallelizes them.
  for src in "${SOURCES[@]}"; do
    if grep -qF "Build images $src " <<<"$in_flight"; then
      echo "$src: a build is already running, skipped"
      continue
    fi
    pending=$(pending_tags "$src")
    if [[ -z "$pending" ]]; then
      echo "$src: up to date"
      continue
    fi
    mapfile -t tags <<<"$pending"
    for tag in "${tags[@]}"; do
      plats=$(platforms_for "$src" "$tag")
      if [[ "$plats" == "[]" ]]; then
        echo "$src $tag: base images share no target platform, skipped" >&2
        failed=1
        continue
      fi
      echo "$src $tag $plats"
      if [[ "$dispatch" == true ]] && ! dispatch_and_wait "$src" "$tag" "$plats"; then
        echo "  $src $tag: build failed" >&2
        failed=1
      fi
    done
  done
  return "$failed"
}

main "$@"
