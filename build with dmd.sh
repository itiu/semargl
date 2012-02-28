DMD=~/dmd/bin/dmd

version=20

git_host=gh
cp -r src/* build/src

rm build/src/test.d
rm *.log

git log -1 --pretty=format:"module myversion; public static char[] author=cast(char[])\"%an\"; public static char[] date=cast(char[])\"%ad\"; public static char[] hash=cast(char[])\"%h\";">myversion.d

rm Semargl-$version-trace
$DMD -debug -g -version=trace myversion.d build/src/trioplax/memory/*.d build/src/trioplax/mongodb/*.d \
build/src/trioplax/*.d build/src/semargl/scripts/*.d build/src/semargl/mod/tango/io/device/*.d \
build/src/semargl/*.d build/src/*.d \
lib/libzmq.a lib/libstdc++.a lib/libuuid.a -ofSemargl-$version-trace

rm Semargl-$version
$DMD -debug -g myversion.d build/src/trioplax/memory/*.d build/src/trioplax/mongodb/*.d \
build/src/trioplax/*.d build/src/semargl/scripts/*.d build/src/semargl/mod/tango/io/device/*.d \
build/src/semargl/*.d build/src/*.d \
lib/libzmq.a lib/libstdc++.a lib/libuuid.a -ofSemargl-$version
rm *.o

 