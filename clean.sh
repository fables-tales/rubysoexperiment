#!/bin/bash
set -exuo pipefail
cargo clean
rm -f Makefile extconf.h foo.o foo.bundle mkmf.log
