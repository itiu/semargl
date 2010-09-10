git_host=gh
mkdir build
rm -r build/src
mkdir build/src
cp -r src/* build/src

mdir=$PWD

cd build

git clone --depth 1 git@$git_host:itiu/rabbitmq-connector.git
cp -r rabbitmq-connector/src/* src

git clone --depth 1 git@$git_host:itiu/trioplax.git
cp -r trioplax/src/* src

git clone --depth 1 git@$git_host:itiu/mongo-d-driver.git
cp -r mongo-d-driver/src/* src

git clone --depth 1 http://github.com/selivanovm/rabbitmq-d.git
cp -r rabbitmq-d/src/* src

git clone --depth 1 git@$git_host:itiu/zeromq-connector.git
cp -r zeromq-connector/src/* src

