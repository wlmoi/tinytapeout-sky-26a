#!/usr/bin/env bash
# Small wrapper to run the librelane build with a sane NIX_PATH fallback.
# Usage: ./scripts/run-build-with-nix.sh

set -euo pipefail

# If NIX_PATH not set, provide a default to nixpkgs
if [ -z "${NIX_PATH:-}" ]; then
  export NIX_PATH="nixpkgs=https://nixos.org/channels/nixpkgs-unstable"
  echo "NIX_PATH not set, using default: $NIX_PATH"
fi

# Run nix-shell with the workspace librelane shell.nix and execute build
nix-shell "$PWD/librelane/shell.nix" --run "python build.py --skip-xor-checks"
