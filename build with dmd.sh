git_host=gh
cp -r src/* build/src

rm build/src/test.d

rm Semargl
dmd -debug -g build/src/trioplax/memory/*.d build/src/trioplax/mongodb/*.d build/src/trioplax/*.d build/src/semargl/scripts/*.d build/src/semargl/mod/tango/io/device/*.d build/src/semargl/*.d build/src/*.d lib/libzmq.a lib/libstdc++.a lib/libuuid.a -ofSemargl
rm Semargl.o

 