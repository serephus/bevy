{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      rust-overlay,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    flake-utils.lib.eachSystem systems (
      system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        rust = pkgs.rust-bin.stable.latest.default.override {
          extensions = [
            "rust-src"
            "rustfmt"
            "clippy"
            "rust-analyzer"
          ];
          targets = [ "wasm32-unknown-unknown" ];
        };
        linker = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          pkgs.clang
          pkgs.mold
        ];

        nativeDeps = [ pkgs.pkg-config ];

        linuxDeps = with pkgs; [
          udev
          alsa-lib
          vulkan-loader
          libX11
          libXcursor
          libXi
          libXrandr # To use the x11 feature
          libxkbcommon
          wayland # To use the wayland feature
        ];

        darwinDeps = [ pkgs.apple-sdk_15 ];

        deps =
          (pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux linuxDeps)
          ++ (pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin darwinDeps);
      in
      {
        devShell = pkgs.mkShell rec {
          name = "bevy";
          nativeBuildInputs = nativeDeps ++ linker;
          buildInputs = [ rust ] ++ deps;
          # xkbcommon uses dlopen to load, so embed the library path as an rpath
          RUSTFLAGS = "-C link-arg=-Wl,-rpath,${pkgs.lib.makeLibraryPath buildInputs}";
        };
      }
    );
}
