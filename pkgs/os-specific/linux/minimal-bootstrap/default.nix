{
  lib,
  config,
  buildPlatform,
  hostPlatform,
  fetchurl,
  checkMetaBuild,
  checkMetaHost,
}: let
  buildBuildBuildPackages = import ./buildbuildbuild.nix {
    inherit
      lib
      config
      fetchurl
      buildPlatform
      ;
    checkMeta = checkMetaBuild;
  };
  buildBuildHostPackages = import ./buildbuildhost.nix {
    inherit
      lib
      config
      fetchurl
      buildPlatform
      hostPlatform
      buildBuildBuildPackages
      buildHostHostPackages
      ;
    checkMeta = checkMetaBuild;
  };
  buildHostHostPackages = import ./buildhosthost.nix {
    inherit
      lib
      config
      fetchurl
      buildPlatform
      hostPlatform
      buildBuildBuildPackages
      buildBuildHostPackages
      ;
    checkMeta = checkMetaHost;
  };
in
  lib.makeScope
  # Prevent using top-level attrs to protect against introducing dependency on
  # non-bootstrap packages by mistake. Any top-level inputs must be explicitly
  # declared here.
  (
    extra:
      lib.callPackageWith (
        {
          inherit
            lib
            config
            fetchurl
            ;
        }
        // extra
      )
  )
  (
    self: {
      inherit buildBuildBuildPackages buildBuildHostPackages buildHostHostPackages;
      inherit
        (buildHostHostPackages)
        bash-static
        binutils-static
        busybox-static
        bzip2-static
        coreutils-static
        diffutils-static
        findutils-static
        gawk-static
        gcc
        gnugrep-static
        gnumake-static
        gnupatch-static
        gnused-static
        gnutar-static
        gzip-static
        libc
        linux-headers
        patchelf-static
        xz-static
        ;
      bash = buildHostHostPackages.bash-static;
    }
  )
