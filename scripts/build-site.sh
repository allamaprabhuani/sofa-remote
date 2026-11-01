#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Buildless site: only public static assets enter the deployment directory.
rm -rf dist
mkdir dist
ditto site dist
