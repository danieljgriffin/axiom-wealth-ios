#!/bin/bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
output="$project_dir/WealthTrackerIOS/LocalAPI.plist"
IFS= read -r -s -p "Paste the new production API key: " api_key
printf '\n' >&2
if [[ ! "$api_key" =~ ^[[:xdigit:]]{64}$ ]]; then
    printf 'Use a 64-character hexadecimal API key.\n' >&2
    exit 1
fi

umask 077
temporary="$(mktemp "$output.XXXXXX")"
trap 'rm -f "$temporary"' EXIT
cat > "$temporary" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>apiToken</key>
    <string>$api_key</string>
</dict>
</plist>
EOF
mv -f "$temporary" "$output"
printf 'Saved the key for the next Xcode build.\n'
