{ pkgs ? import (import ./ops/nix/sources.nix).nixpkgs {}, githash ? ""}:
with pkgs; let
  myNodejs = pkgs.nodejs-14_x;
  nodeEnv = callPackage ./ops/node-env.nix {
    nodejs = myNodejs;
    inherit pkgs stdenv lib python2 runCommand writeTextFile;
    libtool = if pkgs.stdenv.isDarwin then pkgs.darwin.cctools else null;
  };

  nodeAppDerivation = { path, pkgjson, nodeDependencies }: pkgs.stdenv.mkDerivation {
      pname = builtins.replaceStrings [ "@" "/" ] [ "_at_" "_slash_" ] pkgjson.name;
      version = "v${pkgjson.version}";
      src = pkgs.nix-gitignore.gitignoreSource [ "test" ] path;
      buildInputs = [ myNodejs ];
      buildPhase = ''
        export HOME=$TMP
        mkdir -p $out
        ln -s ${nodeDependencies}/lib/node_modules ./node_modules
      '';
      installPhase = ''
        echo DICK
        ls 
        ls node_modules
        echo BUTT
        ${myNodejs}/bin/npm run compile
        ln -s ${nodeDependencies}/lib/node_modules $out/node_modules
        cp -r dist/ $out/
        cp -r package.json $out/
        export PATH=${myNodejs}/bin:$PATH
      '';
    };

  relayApp = nodeAppDerivation { 
    pkgjson = builtins.fromJSON (builtins.readFile ./servers/relay/package.json);
    nodeDependencies = (callPackage ./servers/relay/node-packages.nix {
      inherit nodeEnv fetchurl fetchgit nix-gitignore stdenv lib;
    }).nodeDependencies;
    path = ./servers/relay;
  };

  healthApp = nodeAppDerivation { 
    pkgjson = builtins.fromJSON (builtins.readFile ./servers/health/package.json);
    nodeDependencies = (callPackage ./servers/health/node-packages.nix {
      inherit nodeEnv fetchurl fetchgit nix-gitignore stdenv lib;
    }).nodeDependencies;
    path = ./servers/health;
  };

in {
  relay = pkgs.dockerTools.buildLayeredImage {
    name = "relay";
    created = "now";
    config = {
      Cmd = [ "${myNodejs}/bin/node" "${relayApp}/dist" ];
      Env = [
        "GITHASH=${githash}"
      ];
    };
  };
  health = pkgs.dockerTools.buildLayeredImage {
    name = "health";
    created = "now";
    config = {
      Cmd = [ "${myNodejs}/bin/node" "${healthApp}/dist" ];
    };
  };
}
