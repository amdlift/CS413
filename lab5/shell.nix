# Cross compiling shell for the lab board.  The Pi 4 in the hardware lab runs
# 32 bit Raspberry Pi OS, so the target is armv7l hard float even though the
# Pi 4 itself is a 64 bit chip.
#
#   nix-shell --run ./build.sh
#
# Only davis.s gets turned in.  This file and build.sh are just here so the
# program can be built off the Pi.
#
# Inside the shell the toolchain is prefixed, so use $AS and $CC instead of
# plain as and gcc.  Those would build for this machine, not the Pi.

let
  pkgs = import <nixpkgs> {
    crossSystem = {
      config = "armv7l-unknown-linux-gnueabihf";
    };
  };
in
pkgs.mkShell {
  name = "cs413-lab5";

  buildInputs = [ pkgs.wiringpi ];

  shellHook = ''
    export AS=${pkgs.stdenv.cc.targetPrefix}as
    export CC=${pkgs.stdenv.cc.targetPrefix}gcc
    echo "CS 413 Lab 5 cross build shell"
    echo "  AS = $AS"
    echo "  CC = $CC"
  '';
}
