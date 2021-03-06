/* Build configuration used to build glibc, Info files, and locale
   information.  */

cross:

{ name, fetchurl, fetchgit ? null, stdenv, installLocales ? false
, gccCross ? null, kernelHeaders ? null
, machHeaders ? null, hurdHeaders ? null, libpthreadHeaders ? null
, mig ? null
, profilingLibraries ? false, meta
, withGd ? false, gd ? null, libpng ? null
, preConfigure ? ""
, automake
, autoconf
, bglinkerfix ? "/bgsys/drivers/ppcfloor/gnu-linux/powerpc64-bgq-linux/lib/ld64.so.1"
, ... }@args:

let

  version = "2.17";

in

assert cross != null -> gccCross != null;
assert mig != null -> machHeaders != null;
assert machHeaders != null -> hurdHeaders != null;
assert hurdHeaders != null -> libpthreadHeaders != null;

stdenv.mkDerivation ({
  inherit kernelHeaders installLocales bglinkerfix;

  # The host/target system.
  crossConfig = if cross != null then cross.config else null;

  inherit (stdenv) is64bit;

  enableParallelBuilding = true;

  /* Don't try to apply these patches to the Hurd's snapshot, which is
     older.  */
  patches = stdenv.lib.optionals (hurdHeaders == null)
    [ 


      /* bg libc patch */
      ./bgq-glibc-2.17.patch2


      /* Have rpcgen(1) look for cpp(1) in $PATH.  */
      /* ./rpcgen-path.patch */

      /* gnumake minimal make version fix */
      ./gnumake-version.patch
      /* Allow NixOS and Nix to handle the locale-archive. */
      /* ./nix-locale-archive.patch */

      /* Don't use /etc/ld.so.cache, for non-NixOS systems.  */
      ./dont-use-system-ld-so-cache-bg.patch

      /* Without this patch many KDE binaries crash. */
      /* ./glibc-elf-localscope.patch*/ 

      /* Add blowfish password hashing support.  This is needed for
         compatibility with old NixOS installations (since NixOS used
         to default to blowfish). */
      /* ./glibc-crypt-blowfish.patch */

      /* Fix for random "./sysdeps/posix/getaddrinfo.c:1467:
         rfc3484_sort: Assertion `src->results[i].native == -1 ||
         src->results[i].native == a2_native' failed." crashes. */
      ./glibc-rh739743.patch

      /* The command "getconf CS_PATH" returns the default search path
         "/bin:/usr/bin", which is inappropriate on NixOS machines. This
         patch extends the search path by "/run/current-system/sw/bin". */
      ./fix_path_attribute_in_getconf.patch

      /* Fix buffer overrun in regexp matcher. */
      ./cve-2013-0242.patch

      /* Fix stack overflow in getaddrinfo with many results. */
      ./cve-2013-1914.patch
    ];

  postPatch = ''
    # Needed for glibc to build with the gnumake 3.82
    # http://comments.gmane.org/gmane.linux.lfs.support/31227
    sed -i 's/ot \$/ot:\n\ttouch $@\n$/' manual/Makefile

    # nscd needs libgcc, and we don't want it dynamically linked
    # because we don't want it to depend on bootstrap-tools libs.
    echo "LDFLAGS-nscd += -static-libgcc" >> nscd/Makefile
  '';



  dontDisableStatic = true;

  configureFlags =
    [ "-C"
      "--sysconfdir=/etc"
      "--localedir=/var/run/current-system/sw/lib/locale"

	# bluegene/Q flags
      "--disable-build-nscd"
      "--disable-nscd"
      "--enable-static"
      "--disable-multilib"
      "--enable-static-nss"
      "--enable-shared"
      "--without-cvs"
      "--with-elf"
      "--enable-__cxa_atexit"
      "--with-__thread"
      "--without-gd"

      (if kernelHeaders != null
       then "--with-headers=${kernelHeaders}/include"
       else "--without-headers")
      (if profilingLibraries
       then "--enable-profile"
       else "--disable-profile")
    ] ++ stdenv.lib.optionals (cross != null) [
      (if cross.withTLS then "--with-tls" else "--without-tls")
      (if cross.float == "soft" then "--without-fp" else "--with-fp")
    ];
  


  installFlags = [ "sysconfdir=$(out)/etc" ];

  buildInputs = stdenv.lib.optionals (cross != null) [ gccCross ]
    ++ stdenv.lib.optional (mig != null) mig
    ++ stdenv.lib.optionals withGd [ gd libpng ];

  # Needed to install share/zoneinfo/zone.tab.  Set to impure /bin/sh to
  # prevent a retained dependency on the bootstrap tools in the stdenv-linux
  # bootstrap.
  BASH_SHELL = "/bin/sh";

  # Workaround for this bug:
  #   http://sourceware.org/bugzilla/show_bug.cgi?id=411
  # I.e. when gcc is compiled with --with-arch=i686, then the
  # preprocessor symbol `__i686' will be defined to `1'.  This causes
  # the symbol __i686.get_pc_thunk.dx to be mangled.
  NIX_CFLAGS_COMPILE = stdenv.lib.optionalString (stdenv.system == "i686-linux") "-U__i686";


}

# Remove the `gccCross' attribute so that the *native* glibc store path
# doesn't depend on whether `gccCross' is null or not.
// (removeAttrs args [ "gccCross" "fetchurl" "fetchgit" "withGd" "gd" "libpng" ]) //

{
  name = name + "-${version}" +
    stdenv.lib.optionalString (cross != null) "-${cross.config}";

  src = fetchurl {
      url = "mirror://gnu/glibc/glibc-${version}.tar.gz";
      sha256 = "0ym3zk9ii64279wgw7pw9xkbxczy2ci7ka6mnfs05rhlainhicm3";
    };

  # Remove absolute paths from `configure' & co.; build out-of-tree.
  preConfigure = ''
    export PWD_P=$(type -tP pwd)
    for i in configure io/ftwtest-sh; do
        # Can't use substituteInPlace here because replace hasn't been
        # built yet in the bootstrap.
        sed -i "$i" -e "s^/bin/pwd^$PWD_P^g"
    done

    mkdir ../build
    cd ../build

   export libc_cv_ppc_machine=yes
   export libc_cv_forced_unwind=yes
   export libc_cv_c_cleanup=yes
   export libc_cv_powerpc64_tls=yes

   # remove stack protector for CNK
   export libc_cv_ssp=no
 

    configureScript="`pwd`/../$sourceRoot/configure"

      ${preConfigure}
  '';

#   ${stdenv.lib.optionalString (stdenv.cc.libc != null)
#      ''makeFlags="$makeFlags BUILD_LDFLAGS=-Wl,-rpath,${stdenv.cc.libc}/lib"''
#    }

  meta = {
    homepage = http://www.gnu.org/software/libc/;
    description = "The GNU C Library";

    longDescription =
      '' Any Unix-like operating system needs a C library: the library which
         defines the "system calls" and other basic facilities such as
         open, malloc, printf, exit...

         The GNU C library is used as the C library in the GNU system and
         most systems with the Linux kernel.
      '';

    license = "LGPLv2+";

    maintainers = [ stdenv.lib.maintainers.ludo ];
    #platforms = stdenv.lib.platforms.linux;
  } // meta;
})
