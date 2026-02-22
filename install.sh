#!/bin/bash
# =============================================================================
# install.sh — FPP Phone Listener Installer (wrapper)
# =============================================================================
# Thin wrapper that calls the actual install logic in scripts/fpp_install.sh.
# This allows both direct invocation (sudo ./install.sh) and FPP plugin
# manager installation (which calls scripts/fpp_install.sh directly).
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/scripts/fpp_install.sh" "$@"
