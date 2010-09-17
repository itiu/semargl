git_host=gh
mkdir build
rm -r build/src
mkdir build/src
cp -r src/* build/src

mdir=$PWD

cd build

cd ..
cd ..
cp -r trioplax/src/* semargl/build/src
cp -r zeromq-connector/src/* semargl/build/src
cp -r rabbitmq-connector/src/* semargl/build/src
cp -r mongo-d-driver/src/* semargl/build/src
cp -r rabbitmq-d/src/* semargl/build/src

echo $mdir

cd $mdir

rm build/src/test.d

rm Semargl
dmd -debug -g build/src/trioplax/memory/*.d build/src/trioplax/mongodb/*.d build/src/trioplax/*.d build/src/semargl/scripts/*.d build/src/semargl/mod/tango/io/device/*.d build/src/semargl/*.d build/src/*.d lib/libzmq.a lib/libstdc++.a lib/libuuid.a -ofSemargl
rm Semargl.o

 