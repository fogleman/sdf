#!/bin/sh

set -eu

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

grep -rh _event "$BASE_DIR/../pycam" | \
	grep -v " def " | \
	grep -v configure_event | \
	grep -v expose_event | \
	sed 's/.*_event//g' | \
	grep '"' | \
	cut -f 2 -d '"' | \
	grep -E "^[0-9A-Za-z_-]+$" | \
	sort | \
	uniq -c

