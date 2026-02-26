{
  enableShared,
  libc ? null,
  lib,
  buildPlatform,
  hostPlatform,
  fetchurl,
  bash,
  gcc-build,
  gcc-host,
  gmp,
  mpfr,
  mpc,
  binutils,
  gnumake,
  gnupatch,
  gnused,
  gnugrep,
  gawk,
  diffutils,
  findutils,
  gnutar,
  gzip,
  bzip2,
  xz,
  libiberty,
  binutils-cross,
}: let
  common = import ./common.nix {
    inherit
      lib
      bash
      fetchurl
      gnutar
      xz
      ;
  };
  pname = "libgcc";

  fixgthr = fetchurl {
    name = "fix-gthread.patch";
    url = "https://github.com/gcc-mirror/gcc/commit/e5d853bbe9b05d6a00d98ad236f01937303e40c4.diff";
    hash = "sha256-e5WC3jxE5C2kLY2e3ORXej7vQ1PDhiaCz8FfTXoFB6E=";
  };
  nopiecflags = fetchurl {
    name = "no-pie-cflags.patch";
    url = "https://github.com/gcc-mirror/gcc/commit/77144dd3b6736e0166156bb509590d924375a4f1.diff";
    hash = "sha256-4GhwRrvlquMVOse/btORB1gro5s5HTmdBV70vVl62UY=";
  };

  patches = [
    (fetchurl {
      name = "delete-MACHMODE_H.patch";
      url = "https://github.com/gcc-mirror/gcc/commit/493aae4b034d62054d5e7e54dc06cd9a8be54e29.diff";
      hash = "sha256-oEk0lnI96RlpALWpb7J+GnrtgQsFVqDO57I/zjiqqTk=";
    })
    (fetchurl {
      name = "regular-libdir-includedir.patch";
      url = "https://inbox.sourceware.org/gcc-patches/20250717174911.1536129-1-git@JohnEricson.me/raw";
      hash = "sha256-Cn7rvg1FI7H/26GzSe4pv5VW/gvwbwGqivAqEeawkwk=";
    })
    ../../../../development/compilers/gcc/ng/15/libgcc/force-regular-dirs.patch
  ];

  binutilsTargetPrefix = lib.optionalString (buildPlatform.config != hostPlatform.config) "${hostPlatform.config}-";
in
  bash.runCommand "${pname}-${common.version}"
  {
    inherit pname;
    inherit (common) version meta;

    passthru.sharedAvailable = enableShared;

    nativeBuildInputs = [
      gcc-build
      gnupatch
      binutils-cross
      binutils
      gnumake
      gnused
      gnugrep
      gawk
      diffutils
      findutils
      gnutar
      gzip
      bzip2
      xz
    ];
  }
  (''
      # Unpack
      cp -R ${common.monorepoSrc} ./src
      chmod -R +w src
      pushd src/
      cat ${fixgthr} | tail -n +263 | head -n 47 > newpatch.patch
      cat ${nopiecflags} | tail -n 91 > nopiecflags.patch
      cat ${nopiecflags} | head -n 17 >> nopiecflags.patch
      patch -Np1 -i newpatch.patch
      patch -Np1 -i nopiecflags.patch
      ${lib.concatMapStringsSep "\n" (f: "patch -Np1 -i ${f}") patches}
      popd

      mkdir -p build-${buildPlatform.config}/libiberty/
      pushd build-${buildPlatform.config}/libiberty/
      ln -s ${libiberty}/lib/libiberty.a ./
      popd

      mkdir -p gcc/
      cd gcc/

      (
      export AS_FOR_BUILD=${lib.getExe' binutils "as"}
      export CC_FOR_BUILD="${lib.getExe' gcc-build "gcc"} -I${gmp}/include -I${mpfr}/include -I${mpc}/include"
      export CPP_FOR_BUILD="${lib.getExe' gcc-build "cpp"} -I${gmp}/include -I${mpfr}/include -I${mpc}/include"
      export CXX_FOR_BUILD="${lib.getExe' gcc-build "g++"} -I${gmp}/include -I${mpfr}/include -I${mpc}/include"
      export LD_FOR_BUILD="${lib.getExe' binutils "ld"}"
      export OBJDUMP_FOR_BUILD=${lib.getExe' binutils "objdump"}

      export AS=$AS_FOR_BUILD
      export CC=$CC_FOR_BUILD
      export CPP=$CPP_FOR_BUILD
      export CXX=$CXX_FOR_BUILD
      export LD=$LD_FOR_BUILD
      export OBJDUMP=$OBJDUMP_FOR_BUILD

      export AS_FOR_TARGET=${lib.getExe' binutils-cross "${binutilsTargetPrefix}as"}
      export CC_FOR_TARGET="${lib.getExe' gcc-host "${hostPlatform.config}-gcc"}"
      export CPP_FOR_TARGET=${lib.getExe' gcc-host "${binutilsTargetPrefix}cpp"}
      export LD_FOR_TARGET=${lib.getExe' binutils-cross "${binutilsTargetPrefix}ld"}
      export OBJDUMP_FOR_TARGET=${lib.getExe' binutils-cross "${binutilsTargetPrefix}objdump"}

      export CFLAGS_FOR_BUILD="-DGENERATOR_FILE=1"
      ../src/gcc/configure \
        --build=${buildPlatform.config} \
        --host=${buildPlatform.config} \
        --target=${hostPlatform.config} \
        --disable-bootstrap \
        --disable-multilib \
        --enable-languages=c \
        --disable-fixincludes \
        --disable-intl \
        --disable-lto \
        --disable-libatomic \
        --disable-libbacktrace \
        --disable-libcpp \
        --disable-libssp \
        --disable-libquadmath \
        --disable-libgomp \
        --disable-libvtv \
        --disable-vtable-verify \
        ${lib.optionalString (!hostPlatform.isMusl) "--with-glibc-version=2.42"}


      sed -i 's,libgcc.mvars:.*$,libgcc.mvars:,' -i Makefile

      make \
        config.h \
        libgcc.mvars \
        tconfig.h \
        tm.h \
        options.h \
        insn-constants.h \
        version.h
      )
      mkdir -p include

      mkdir -p ${hostPlatform.config}/libgcc
      cd ${hostPlatform.config}/libgcc

      export AS_FOR_BUILD=${lib.getExe' binutils "as"}
      export CC_FOR_BUILD=${lib.getExe' gcc-build "gcc"}
      export CPP_FOR_BUILD=${lib.getExe' gcc-build "cpp"}
      export CXX_FOR_BUILD=${lib.getExe' gcc-build "g++"}
      export LD_FOR_BUILD=${lib.getExe' binutils "ld"}

      export AS=${lib.getExe' binutils-cross "${binutilsTargetPrefix}as"}
      export CC="${lib.getExe' gcc-host "${hostPlatform.config}-gcc"}"
      export CPP=${lib.getExe' gcc-host "${binutilsTargetPrefix}cpp"}
      export LD=${lib.getExe' binutils-cross "${binutilsTargetPrefix}ld"}
      export AS_FOR_TARGET=${lib.getExe' binutils-cross "${binutilsTargetPrefix}as"}
      export CC_FOR_TARGET="${lib.getExe' gcc-host "${hostPlatform.config}-gcc"}"
      export CPP_FOR_TARGET=${lib.getExe' gcc-host "${binutilsTargetPrefix}-cpp"}
      export LD_FOR_TARGET=${lib.getExe' binutils-cross "${binutilsTargetPrefix}ld"}
    ''
    + (lib.optionalString hostPlatform.isMusl ''

      export CFLAGS="-isystem ${gcc-host}/lib/gcc/${hostPlatform.config}/${common.version}/include-fixed"

    '')
    + ''
      ../../../src/libgcc/configure --disable-dependency-tracking \
       --prefix="$out" \
       --build=${buildPlatform.config} \
       --host=${hostPlatform.config} \
        gcc_cv_target_thread_file=single \
        ${
        if enableShared
        then "--enable-shared --disable-static"
        else "--disable-shared --enable-static"
      } \
        cross_compiling=true

      export CFLAGS=""
      export LDFLAGS="${lib.optionalString (libc != null) "-B${libc}/lib"}"
      make -j $NIX_BUILD_CORES MULTIBUILDTOP:=../

      make -j $NIX_BUILD_CORES install-strip MULTIBUILDTOP:=../
      mkdir -p "$out/include"
      install -c -m 644 gthr-default.h "$out/include/"

      if [ -d "$out/lib/gcc/${hostPlatform.config}/lib64" ]; then
        shopt -s dotglob
        for lib in $out/lib/gcc/${hostPlatform.config}/lib64/*; do
          mv --no-clobber "$lib" "$out/lib/gcc/${hostPlatform.config}/${common.version}/"
        done
        shopt -u dotglob
        rm -rf "$out/lib/gcc/${hostPlatform.config}/lib64"
        ln -s lib "$out/lib/gcc/${hostPlatform.config}/lib64"
      fi

      if ! [ -e "$out/lib/gcc/${hostPlatform.config}/${common.version}/libgcc_eh.a" ]; then
        ln -s "$out/lib/gcc/${hostPlatform.config}/${common.version}/libgcc.a" "$out/lib/gcc/${hostPlatform.config}/${common.version}/libgcc_eh.a"
      fi
      if [ -e "$out/lib/gcc/${hostPlatform.config}/${common.version}/libgcc_s.so.1" ]; then
        ${binutilsTargetPrefix}strip --strip-debug "$out/lib/gcc/${hostPlatform.config}/${common.version}/libgcc_s.so.1"
      fi
    '')
