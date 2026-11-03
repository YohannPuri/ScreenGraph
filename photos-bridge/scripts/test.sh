#!/usr/bin/env bash
# Runs the Swift tests. With only the Command Line Tools installed (no Xcode),
# the Testing framework exists but isn't on the default search paths, and its
# Foundation cross-import overlay ships without a module, so we add the paths
# and turn cross-import overlays off. With Xcode, a plain `swift test` works.
set -euo pipefail
cd "$(dirname "$0")/.."

developer_dir="$(xcode-select -p)"
if [[ "$developer_dir" == *CommandLineTools* ]]; then
  frameworks="$developer_dir/Library/Developer/Frameworks"
  exec swift test \
    -Xswiftc "-F$frameworks" \
    -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
    -Xlinker "-F$frameworks" \
    -Xlinker -rpath -Xlinker "$frameworks" \
    "$@"
fi
exec swift test "$@"
