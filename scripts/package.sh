#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(sed -n 's/^## Version: //p' AutoEnchanter/AutoEnchanter.toc | tr -d '\r')
interface=$(sed -n 's/^## Interface: //p' AutoEnchanter/AutoEnchanter.toc | tr -d '\r')
printf '%s\n' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'
printf '%s\n' "$interface" | grep -Eq '^[0-9]+$'
asset="AutoEnchanter-$version.zip"
rm -f "$asset" release.json
# Read runtime Lua paths from the TOC, so new modules cannot be silently omitted.
files=(AutoEnchanter/AutoEnchanter.toc AutoEnchanter/AutoEnchanterIcon.blp)
while IFS= read -r line; do
  line="${line%$'\r'}"
  if [[ "$line" =~ ^[A-Za-z0-9_]+\.lua$ ]]; then
    files+=("AutoEnchanter/$line")
  elif [[ -n "$line" && "$line" != \#* ]]; then
    echo "Unsupported TOC runtime path: $line" >&2; exit 1
  fi
done < AutoEnchanter/AutoEnchanter.toc
for f in AutoEnchanter/*.lua; do
  found=false; for packaged in "${files[@]}"; do [[ "$f" != "$packaged" ]] || found=true; done
  "$found" || { echo "Lua file not listed in TOC: $f" >&2; exit 1; }
done
zip -X "$asset" "${files[@]}"
unzip -t "$asset"
jq -n --arg filename "$asset" --argjson interface "$interface" '{releases:[{filename:$filename,nolib:false,metadata:[{flavor:"forever",interface:$interface}]}]}' > release.json
jq -e --arg filename "$asset" --argjson interface "$interface" '.releases | any(.filename == $filename and .nolib == false and (.metadata | any(.flavor == "forever" and .interface == $interface)))' release.json
