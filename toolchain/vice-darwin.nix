# nixpkgs' VICE recipe is Linux-only. Use its pinned source with the SDL2 UI
# and native macOS audio instead of its Linux GTK/OpenGL/audio dependencies.
{
  lib,
  stdenv,
  src,
  version,
  SDL2,
  SDL2_image,
  bison,
  curl,
  dos2unix,
  flex,
  libiconv,
  perl,
  pkg-config,
  texinfo,
  xa,
  libpng,
  zlib,
}:

stdenv.mkDerivation {
  pname = "vice";
  inherit src version;

  strictDeps = true;
  nativeBuildInputs = [
    bison
    dos2unix
    flex
    libiconv
    perl
    pkg-config
    texinfo
    xa
  ];
  buildInputs = [
    SDL2
    SDL2_image
    curl
    libpng
    zlib
  ];

  postPatch = ''
    # libproc requires at least PATH_MAX bytes. Subtracting
    # one makes startup fail before VICE has saved argv[0] for its fallback.
    substituteInPlace src/arch/shared/archdep_program_path.c \
      --replace-fail 'proc_pidpath(pid, buffer, sizeof(buffer) - 1)' 'proc_pidpath(pid, buffer, sizeof(buffer))'

    # Match the GTK frontend: SDL also needs its state directory before logging.
    substituteInPlace src/arch/sdl/archdep.c \
      --replace-fail 'archdep_create_user_config_dir();' 'archdep_create_user_config_dir(); archdep_create_user_state_dir();'
  '';

  # Upstream probes Homebrew/MacPorts and adds host paths to compiler flags.
  # All dependencies must come from Nix, regardless of what is installed locally.
  preConfigure = ''
    for vice_prefix in /opt/local /opt/homebrew /usr/local; do
      for vice_subdir in include include/libomp lib lib/libomp; do
        vice_probe=$(printf '%s' "$vice_prefix/$vice_subdir" | tr / _)
        export "ac_cv_file_$vice_probe=no"
      done
    done

    # reSID inherits these tools from the parent configure, but builds in its
    # own subdirectory. Relative wrapper paths then point at the wrong place.
    substituteInPlace configure \
      --replace-fail '\$(top_srcdir)/src/arch/shared/macOS-wrap-' "$PWD/src/arch/shared/macOS-wrap-"
    patchShebangs src/arch/shared/macOS-wrap-*.sh
  '';

  configureFlags = [
    "--enable-sdl2ui"
    "--disable-gtk3ui"
    "--disable-arch"
    "--disable-pdf-docs"
    "--enable-macos-minimum-version=${stdenv.hostPlatform.darwinMinVersion}"
  ];

  enableParallelBuilding = true;

  meta = {
    description = "Emulators for 8-bit Commodore computers, with the SDL2 UI";
    homepage = "https://vice-emu.sourceforge.io/";
    license = lib.licenses.gpl2Plus;
    mainProgram = "x64sc";
    platforms = lib.platforms.darwin;
  };
}
