#!/usr/bin/env bash
# Assembles and links davis.s for the Pi.  Run it from inside nix-shell so
# that $AS and $CC point at the cross toolchain.
set -e

: "${AS:=as}"
: "${CC:=gcc}"

"$AS" -g -o davis.o davis.s
"$CC" -o davis davis.o -lwiringPi

echo "Built davis for $(file -b davis | cut -d, -f2)"
