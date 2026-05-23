#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export NONINTERACTIVE="${NONINTERACTIVE:-1}"

exec "${ROOT_DIR}/bootstrap.sh" "$@"