{
  description = "Pixie SDDM theme - A clean, modern, and minimal SDDM theme";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = pkgs.lib;

        makeTheme =
          {
            background ? null,
            avatar ? null,
            accentColor ? null,
            autoColor ? null,
            backgroundColor ? null,
            textColor ? null,
            fontFamily ? null,
            userLabelMode ? null,
            showSuspend ? null,
            showRestart ? null,
            showShutdown ? null,
            ...
          }@args:
          let
            # Helper to convert Nix types to SDDM-compatible strings
            toIniValue = v: if builtins.isBool v then (if v then "true" else "false") else toString v;

            # Explicitly capture known arguments to satisfy the linter.
            knownArgs = {
              inherit
                background
                accentColor
                autoColor
                backgroundColor
                textColor
                fontFamily
                userLabelMode
                showSuspend
                showRestart
                showShutdown
                ;
            };

            # Combine known arguments with any extra ones passed via @args,
            # then filter out nulls and special fields like 'avatar'.
            cfgArgs = lib.filterAttrs (n: v: v != null) (
              knownArgs // (removeAttrs args (builtins.attrNames knownArgs ++ [ "avatar" ]))
            );
          in
          pkgs.stdenvNoCC.mkDerivation {
            pname = "pixie-sddm";
            version = "3.0${lib.optionalString (self ? shortRev) "-${self.shortRev}"}";

            src = lib.fileset.toSource {
              root = ./.;
              fileset = lib.fileset.unions [
                ./Main.qml
                ./metadata.desktop
                ./theme.conf
                ./assets
                ./components
                ./LICENSE
              ];
            };

            nativeBuildInputs = [
              pkgs.kdePackages.qtdeclarative
              (pkgs.python3.withPackages (p: [ p.pillow ]))
            ];
            dontWrapQtApps = true;

            # Pre-build QML cache siblings (.qmlc next to each .qml). Without this,
            # SDDM's runtime cache stays stale across theme updates because Nix sets
            # all store-path mtimes to epoch 0, defeating Qt's mtime-based cache
            # invalidation. The runtime checks for a sibling .qmlc first, and
            # qmlcachegen writes sourceTimeStamp=0 in the header so Qt skips the
            # timestamp check entirely.
            postBuild = ''
              qmlcg=${pkgs.kdePackages.qtdeclarative}/libexec/qmlcachegen
              qmlpath=${pkgs.kdePackages.qtdeclarative}/lib/qt-6/qml

              for qml in Main.qml components/*.qml; do
                "$qmlcg" -I "$qmlpath" -o "$qml"c "$qml"
              done
            '';

            postPatch = ''
              # Helper to update or append keys in theme.conf
              update_ini() {
                local key="$1"
                local value="$2"
                [ -z "$value" ] && return

                if grep -q "^$key=" theme.conf; then
                  sed -i "s|^$key=.*|$key=$value|" theme.conf
                else
                  echo "$key=$value" >> theme.conf
                fi
              }

              # Pre-compute accent from the wallpaper unless the user supplied one.
              # Skipping runtime extraction (autoColor=false) makes the greeter render
              # the correct accent from the very first frame.
              ${lib.optionalString (accentColor == null) ''
                bg="${if background != null then "${background}" else "assets/background.jpg"}"
                accent=$(python3 ${./extract-accent.py} "$bg")
                update_ini "accentColor" "$accent"
                update_ini "autoColor" "false"
              ''}

              # Dynamically generate update_ini calls for all configuration arguments
              # (these run AFTER pre-compute, so user overrides win)
              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (k: v: ''update_ini "${k}" "${toIniValue v}"'') cfgArgs
              )}
            '';

            installPhase = ''
              mkdir -p $out/share/sddm/themes/pixie
              cp -r * $out/share/sddm/themes/pixie/

              # Replace avatar asset if a custom path is provided
              ${lib.optionalString (avatar != null) ''
                cp -f ${avatar} $out/share/sddm/themes/pixie/assets/avatar.jpg
              ''}
            '';
          };
      in
      {
        packages.pixie-sddm = lib.makeOverridable makeTheme { };
        packages.default = self.packages.${system}.pixie-sddm;
      }
    );
}
