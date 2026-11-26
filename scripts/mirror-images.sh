#!/usr/bin/env bash
set -euo pipefail

: "${ALIYUN_REGISTRY_USER:?Set the ALIYUN_REGISTRY_USER secret}"
: "${ALIYUN_REGISTRY_PASSWORD:?Set the ALIYUN_REGISTRY_PASSWORD secret}"
: "${ACR_REGISTRY:?Set ACR_REGISTRY}"
: "${ACR_NAMESPACE:?Set ACR_NAMESPACE}"

release=v1.9.1.4
archive=elkeidup_image_v1.9.1.tar.gz
url="https://github.com/bytedance/Elkeid/releases/download/$release"
work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT
export DOCKER_CONFIG="$work_dir/docker-config"
mkdir -m 700 "$DOCKER_CONFIG"

for part in 00 01 02 03; do
  curl --fail --location --retry 4 --connect-timeout 30 \
    --output "$work_dir/part" "$url/$archive.$part"
  test -s "$work_dir/part"
  cat "$work_dir/part" >> "$work_dir/$archive"
  rm -- "$work_dir/part"
done

gzip -t "$work_dir/$archive"
docker image load --input "$work_dir/$archive" | tee "$work_dir/load.log"
rm -- "$work_dir/$archive"

mapfile -t sources < <(sed -n 's/^Loaded image: //p' "$work_dir/load.log" | sort -u)
if (( ${#sources[@]} == 0 )) || grep -q '^Loaded image ID:' "$work_dir/load.log"; then
  echo "Expected tagged images only in the release archive" >&2
  exit 1
fi

declare -A seen=()
targets=()
for source in "${sources[@]}"; do
  name_and_tag=${source##*/}
  if [[ ! "$name_and_tag" =~ ^[a-z0-9][a-z0-9._-]*:[A-Za-z0-9_][A-Za-z0-9_.-]*$ ]]; then
    echo "Unexpected image reference: $source" >&2
    exit 1
  fi
  if [[ "$name_and_tag" == all-in-one:* ]]; then
    name_and_tag="elkeid-$name_and_tag"
  fi
  target="$ACR_REGISTRY/$ACR_NAMESPACE/${name_and_tag}"
  if [[ -n "${seen[$target]:-}" ]]; then
    echo "Conflicting source images for $target: ${seen[$target]} and $source" >&2
    exit 1
  fi
  seen[$target]=$source
  targets+=("$target")
done

printf '%s' "$ALIYUN_REGISTRY_PASSWORD" | docker login "$ACR_REGISTRY" \
  --username "$ALIYUN_REGISTRY_USER" --password-stdin

for i in "${!sources[@]}"; do
  source=${sources[$i]}
  target=${targets[$i]}
  docker image tag "$source" "$target"
  docker image push "$target"
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf -- '- `%s` → `%s`\n' "$source" "$target" >> "$GITHUB_STEP_SUMMARY"
  fi
done
