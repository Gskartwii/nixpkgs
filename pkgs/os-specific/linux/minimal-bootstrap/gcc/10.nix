{
  lib,
  buildPlatform,
  hostPlatform,
  fetchurl,
  bash,
  coreutils,
  gcc,
  musl,
  binutils,
  gnumake,
  gnused,
  gnugrep,
  gnupatch,
  gawk,
  diffutils,
  findutils,
  gnutar,
  gzip,
  bzip2,
  xz,
}:
let
  pname = "gcc";
  # Cannot use 10.5.0, see:
  # https://gcc.gnu.org/bugzilla/show_bug.cgi?format=multiple&id=110716
  version = "10.4.0";

  src = fetchurl {
    url = "mirror://gnu/gcc/gcc-${version}/gcc-${version}.tar.xz";
    hash = "sha256-ySl9W818tD89/C/tU4npSMkxL9li72pM5FXP+WPr5PE=";
  };

  # last version to compile with gcc 4.6
  gmpVersion = "6.2.1";
  gmp = fetchurl {
    url = "mirror://gnu/gmp/gmp-${gmpVersion}.tar.xz";
    hash = "sha256-/UgpkSzd0S+EGBw0Ucx1K+IkZD6H+sSXtp7d2txJtPI=";
  };

  mpfrVersion = "4.2.2";
  mpfr = fetchurl {
    url = "mirror://gnu/mpfr/mpfr-${mpfrVersion}.tar.xz";
    hash = "sha256-tnugOD736KhWNzTi6InvXsPDuJigHQD6CmhprYHGzgE=";
  };

  mpcVersion = "1.3.1";
  mpc = fetchurl {
    url = "mirror://gnu/mpc/mpc-${mpcVersion}.tar.gz";
    hash = "sha256-q2QkkvXPiCt0qgy3MM1BCoHtzb7IlRg86TDnBsHHWbg=";
  };

  islVersion = "0.24";
  isl = fetchurl {
    url = "https://gcc.gnu.org/pub/gcc/infrastructure/isl-${islVersion}.tar.bz2";
    hash = "sha256-/PeN2WVsEOuM+fvV9ZoLawE4YgX+GTSzsoegoYmBRcA=";
  };

  patches = [
    # Unify library paths across architectures.
    ./v10-riscv-linux-libpath.patch
    (fetchurl {
      # RISC-V: Make __divdi3 handle div the same as hardware
      url = "https://github.com/gcc-mirror/gcc/commit/d465a40200324d56c51f02f2c5807e716f9c8775.diff";
      hash = "sha256-WVVC6YD6I7k7LUOvR31gnrmrc257MWjYs7UmijONGYc=";
    })
    (fetchurl {
      # RISC-V: jal cannot refer to a default visibility symbol for shared
      url = "https://github.com/gcc-mirror/gcc/commit/45116f342057b7facecd3d05c2091ce3a77eda59.diff";
      hash = "sha256-z7NkQu5l2brCcf7LJTL5vDrFeExDQHFm6rnj9N00FAU=";
    })
  ];
in
bash.runCommand "${pname}-${version}"
  {
    inherit pname version;

    nativeBuildInputs = [
      gcc
      binutils
      gnumake
      gnused
      gnugrep
      gnupatch
      gawk
      diffutils
      findutils
      gnutar
      gzip
      bzip2
      xz
    ];

    passthru.tests.hello-world =
      result:
      bash.runCommand "${pname}-simple-program-${version}"
        {
          nativeBuildInputs = [
            binutils
            musl
            result
          ];
        }
        ''
          cat <<EOF >> test.c
          #include <stdio.h>
          int main() {
            printf("Hello World!\n");
            return 0;
          }
          EOF
          musl-gcc -o test test.c
          ./test
          mkdir $out
        '';

    meta = {
      description = "GNU Compiler Collection, version ${version}";
      homepage = "https://gcc.gnu.org";
      license = lib.licenses.gpl3Plus;
      teams = [ lib.teams.minimal-bootstrap ];
      platforms = lib.platforms.unix;
      mainProgram = "gcc";
    };
  }
  ''
    # Unpack
    tar xf ${src}
    tar xf ${gmp}
    tar xf ${mpfr}
    tar xf ${mpc}
    tar xf ${isl}
    cd gcc-${version}

    ln -s ../gmp-${gmpVersion} gmp
    ln -s ../mpfr-${mpfrVersion} mpfr
    ln -s ../mpc-${mpcVersion} mpc
    ln -s ../isl-${islVersion} isl

    # Patch
    ${lib.concatMapStringsSep "\n" (f: "patch -Np1 -i ${f}") patches}
    # doesn't recognise musl
    sed -i 's|"os/gnu-linux"|"os/generic"|' libstdc++-v3/configure.host

    # Configure
    export CC="gcc -Wl,-dynamic-linker -Wl,${musl}/lib/libc.so"
    export CXX="g++ -Wl,-dynamic-linker -Wl,${musl}/lib/libc.so"
    export CFLAGS_FOR_TARGET="-Wl,-dynamic-linker -Wl,${musl}/lib/libc.so"
    export C_INCLUDE_PATH="${musl}/include"
    export CPLUS_INCLUDE_PATH="$C_INCLUDE_PATH"
    export LIBRARY_PATH="${musl}/lib"

    bash ./configure \
      --prefix=$out \
      --build=${buildPlatform.config} \
      --host=${hostPlatform.config} \
      --with-native-system-header-dir=/include \
      --with-sysroot=${musl} \
      --enable-initfini-array \
      --enable-languages=c,c++ \
      --disable-analyzer \
      --disable-bootstrap \
      --disable-decimal-float \
      --disable-dependency-tracking \
      --disable-gcov \
      --disable-libitm \
      --disable-libgomp \
      --disable-libmpx \
      --disable-libquadmath \
      --disable-libsanitizer \
      --disable-libssp \
      --disable-libvtv \
      --disable-lto \
      --disable-multilib \
      --disable-plugin

    # Build
    make -j $NIX_BUILD_CORES

    # Install
    make -j $NIX_BUILD_CORES install-strip
  ''
