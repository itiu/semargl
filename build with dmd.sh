mkdir build
rm -r build/src
mkdir build/src
cp -r src/* build/src

mdir=$PWD

cd build

git clone --depth 1 git@github.com:itiu/rabbitmq-connector.git
cp -r rabbitmq-connector/src/* src

git clone --depth 1 git@github.com:itiu/trioplax.git
cp -r trioplax/src/* src

git clone --depth 1 git@github.com:itiu/mongo-d-driver.git
cp -r mongo-d-driver/src/* src

git clone --depth 1 http://github.com/selivanovm/rabbitmq-d.git
cp -r rabbitmq-d/src/* src

cd ..
cd ..
cp -r trioplax/src/* semargl/build/src

echo $mdir

cd $mdir

rm Semargl
dmd build/src/trioplax/memory/*.d build/src/trioplax/mongodb/*.d build/src/trioplax/*.d build/src/semargl/scripts/*.d build/src/semargl/mod/tango/io/device/*.d build/src/semargl/*.d build/src/*.d -ofSemargl
rm Semargl.o

 