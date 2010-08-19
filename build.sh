mkdir build
mkdir build/src
cp -r src/* build/src
cd build
git clone --depth 1 git://github.com/itiu/rabbitmq-connector.git
cp -r rabbitmq-connector/src/* src
git clone --depth 1 git@github.com:itiu/trioplax.git
cp -r trioplax/src/* src
git clone --depth 1 git://github.com/itiu/mongo-d-driver.git
cp -r mongo-d-driver/src/* src
git clone --depth 1 git://github.com/selivanovm/rabbitmq-d.git
cp -r rabbitmq-d/src/* src
dmd src/trioplax/memory/*.d src/trioplax/mongodb/*.d src/trioplax/*.d src/scripts/*.d src/mod/tango/io/device/*.d src/*.d -ofSemargl

 