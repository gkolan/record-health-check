#!/usr/bin/env bash
set -euo pipefail
echo "scripts/setup-demo.sh is deprecated." >&2
echo "Use subscriber mode instead:" >&2
echo "  DEV_HUB_ALIAS=my-dev-hub npm run setup" >&2
exit 1
