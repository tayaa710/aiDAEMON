#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/aiDAEMON-DevDerivedData}"
RUN_APP_PATH="${RUN_APP_PATH:-$PROJECT_ROOT/.dev/aiDAEMON.app}"
SCHEME="${SCHEME:-aiDAEMON}"
CONFIGURATION="${CONFIGURATION:-Debug}"

printf 'Building signed %s app...\n' "$CONFIGURATION"
COMMON_ARGS=(
  -project "$PROJECT_ROOT/aiDAEMON.xcodeproj"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -sdk macosx
  -derivedDataPath "$DERIVED_DATA_PATH"
)

/usr/bin/xcodebuild "${COMMON_ARGS[@]}" CODE_SIGN_ALLOW_ENTITLEMENTS_MODIFICATION=YES build

SOURCE_APP="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/aiDAEMON.app"
if [[ ! -d "$SOURCE_APP" ]]; then
  echo "Expected app not found: $SOURCE_APP" >&2
  exit 1
fi

mkdir -p "$(dirname "$RUN_APP_PATH")"
rsync -a --delete "$SOURCE_APP/" "$RUN_APP_PATH/"

echo "Copied app to stable path: $RUN_APP_PATH"
echo "Code signing identity summary:"
/usr/bin/codesign -dv --verbose=4 "$RUN_APP_PATH" 2>&1 | /usr/bin/sed -n '1,12p'

echo "Launching app..."
/usr/bin/open "$RUN_APP_PATH"

echo
echo "If permissions were already granted to this signed identity, they should persist across rebuilds."
