# Herdr.app from kenchan/herdr-app: an upstream release tag plus patches not released yet.
# The fork's "fork release" workflow builds it when a `<version>-r<n>` tag is pushed (see README).
{ stdenvNoCC, fetchurl }:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "herdr-app";
  version = "0.1.18-r1";

  src = fetchurl {
    url = "https://github.com/kenchan/herdr-app/releases/download/${finalAttrs.version}/herdr-app-macos-aarch64.tar.gz";
    hash = "sha256-wUFXCT429YRbEl+HLktvtkJWcIvvNSjhMzneIRNBzJU=";
  };

  sourceRoot = ".";

  # Why not the default fixup: it rewrites the binary, which breaks the app's ad hoc signature.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/Applications $out/bin
    cp -R Herdr.app $out/Applications/
    ln -s $out/Applications/Herdr.app/Contents/MacOS/Herdr $out/bin/herdr-app
    runHook postInstall
  '';

  meta.platforms = [ "aarch64-darwin" ];
})
