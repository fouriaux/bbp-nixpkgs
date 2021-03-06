{ stdenv, 
fetchgit, 
boost, 
cmake, 
bison,
flex,
hwloc, 
x11, 
pkgconfig, 
lunchbox,
vmmlib,
pression,
collage,
opengl,
hwsd,
qt
 }:

stdenv.mkDerivation rec {
  name = "equalizer-${version}";
  version = "2.1.0-dev201710";

  buildInputs = [ stdenv pkgconfig boost bison flex hwloc x11 cmake lunchbox pression collage opengl hwsd vmmlib qt.qtbase ];

  src = fetchgit {
    url = "https://github.com/Eyescale/Equalizer.git";
    rev = "ba5259d6a1be4c2441c26a51c7c5ec6ac506c47b";
    sha256 = "02kgggic0cwgzr90gn2dxvj2817mafrf7fy9x5dnqk9kqwyzim1x";
  };


  # need to have the lib directory in LDPATH for binary creation 
  preBuild = ''
	export LD_LIBRARY_PATH="''${PWD}/lib:''${LDLIBRARY_PATH}"
  '';

  cmakeFlags = [ "-DDISABLE_SUBPROJECTS=TRUE" ];

  enableParallelBuilding = true;

  propagatedBuildInputs = [ lunchbox pression collage hwsd vmmlib ];
  
}


