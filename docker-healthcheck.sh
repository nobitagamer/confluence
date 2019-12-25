#!/bin/sh

set -euo pipefail

if nc -z localhost 8090; then
	exit 0
fi

exit 1
