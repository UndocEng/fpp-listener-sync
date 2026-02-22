#!/bin/bash
# =============================================================================
# uninstall.sh — FPP Phone Listener Uninstaller (wrapper)
# =============================================================================
# Thin wrapper that calls the actual uninstall logic in scripts/fpp_uninstall.sh.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/scripts/fpp_uninstall.sh" "$@"
