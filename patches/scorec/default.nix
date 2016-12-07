{ stdenv
, fetchFromGitHub
, cmake
, mpi
}:


stdenv.mkDerivation rec {
    name = "scorec-${version}";
    version = "2.1.0";

    src = fetchFromGitHub {
		owner = "SCOREC";
		repo = "core";
        rev  = "e0103960beeebf7b449788272b0cccca7aa037c3";
        sha256 = "143pbq84lcikab4xk2ga5h99rsdvxscn5y9iri2s6217xw3jxnza";
    };

	preConfigure = ''
			export CC=mpicc
			export CXX=mpic++
	'';

	cmakeFlags = [ 
					"-DSCOREC_CXX_WARNINGS=OFF" "-DSCOREC_CXX_WARNINGS=OFF" 
					"-DIS_TESTING=FALSE"					
				 ];

    buildInputs = [ cmake mpi ];

	buildFlags = [ "VERBOSE=1" ];

    enableParallelBuilding = true;


}
