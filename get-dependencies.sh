mongo_d_driver__hash=58ed682
trioplax__hash=c9c8a8f
zeromq__hash=76c6a8b
rabbitmq_connector__hash=02524e3
rabbitmq_d__hash=9322e2e

username=itiu

trioplax__project_name=itiu-trioplax
mongo_d_driver__project_name=itiu-mongo-d-driver
zeromq__project_name=itiu-zeromq-connector
rabbitmq_connector__project_name=rabbitmq-connector
rabbitmq_d__project_name=rabbitmq-d

mkdir build
mkdir build/src

cd build

wget --no-check-certificate http://github.com/itiu/mongo-d-driver/zipball/$mongo_d_driver__hash
unzip $mongo_d_driver__hash
rm $mongo_d_driver__hash

wget --no-check-certificate http://github.com/itiu/trioplax/zipball/$trioplax__hash
unzip $trioplax__hash
rm $trioplax__hash

wget --no-check-certificate http://github.com/itiu/zeromq-connector/zipball/$zeromq__hash
unzip $zeromq__hash
rm $zeromq__hash

wget --no-check-certificate http://github.com/itiu/$rabbitmq_connector__project_name/zipball/$rabbitmq_connector__hash
unzip $rabbitmq_connector__hash
rm $rabbitmq_connector__hash

wget --no-check-certificate http://github.com/selivanovm/$rabbitmq_d__project_name/zipball/$rabbitmq_d__hash
unzip $rabbitmq_d__hash
rm $rabbitmq_d__hash

cd ..

cp -v -r build/$trioplax__project_name-$trioplax__hash/src/* build/src
cp -v -r build/$mongo_d_driver__project_name-$mongo_d_driver__hash/src/* build/src
cp -v -r build/$zeromq__project_name-$zeromq__hash/src/* build/src
cp -v -r build/$username-$rabbitmq_connector__project_name-$rabbitmq_connector__hash/src/* build/src
cp -v -r build/selivanovm-$rabbitmq_d__project_name-$rabbitmq_d__hash/src/* build/src

