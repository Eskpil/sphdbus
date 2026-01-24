let
  pkgs = import <nixpkgs> { };
in
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    zls
    zig
    valgrind
    gdb
    python3
    glfw
    libGL
    clang-tools
    wayland
    linuxPackages_latest.perf
    kcov
    linuxHeaders
  ];

  LD_LIBRARY_PATH = "${pkgs.wayland}/lib";
}
