#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 <claude-design-export.zip> <round-NN>" >&2
  exit 2
}

[[ $# -eq 2 ]] || usage

archive=$1
round=$2

[[ -f "$archive" ]] || {
  echo "Export not found: $archive" >&2
  exit 1
}

[[ "$round" =~ ^round-[0-9][0-9]$ ]] || {
  echo "Round must match round-NN, for example round-02." >&2
  exit 1
}

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
destination="$repo_root/docs/design/claude-design/$round"

[[ ! -e "$destination" ]] || {
  echo "Destination already exists: $destination" >&2
  exit 1
}

while IFS= read -r entry; do
  case "/$entry/" in
    */../*|/*//*|/*/./*)
      echo "Unsafe path in archive: $entry" >&2
      exit 1
      ;;
  esac
  [[ "$entry" != /* ]] || {
    echo "Absolute path in archive: $entry" >&2
    exit 1
  }
done < <(unzip -Z1 "$archive")

temporary=$(mktemp -d "${TMPDIR:-/tmp}/kitchenlink-claude-design.XXXXXX")
trap 'rm -rf "$temporary"' EXIT

unzip -q "$archive" -d "$temporary"

html_count=$(find "$temporary" -type f -name '*.dc.html' | wc -l | tr -d ' ')
[[ "$html_count" == "1" ]] || {
  echo "Expected exactly one .dc.html file, found $html_count." >&2
  exit 1
}

html_file=$(find "$temporary" -type f -name '*.dc.html' -print)
support_file=$(find "$temporary" -type f -name 'support.js' -print | head -n 1)
thumbnail_file=$(find "$temporary" -type f -name '.thumbnail' -print | head -n 1)

mkdir -p "$destination/export"
cp "$archive" "$destination/source-export.zip"
cp "$html_file" "$destination/export/territories.html"

if [[ -n "$support_file" ]]; then
  cp "$support_file" "$destination/export/support.js"
fi

if [[ -n "$thumbnail_file" ]]; then
  cp "$thumbnail_file" "$destination/thumbnail.webp"
fi

echo "Imported Claude Design export to:"
echo "$destination"
