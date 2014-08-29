#! /bin/bash -ex

export VIRTUAL_ENV=${VIRTUAL_ENV:-"$PWD/socorro-virtualenv"}
export JAVA_HOME=${JAVA_HOME:-"/usr/lib/jvm/jre-openjdk"}

if [ -z "$WORKSPACE" -o -z "$CI" ]; then
  export PATH=$JAVA_HOME/bin:$PATH
fi

export BUILD_DIR=${BUILD_DIR:-builds/socorro}
export SOCORRO_DIR=${BUILD_DIR}/data/socorro

export database_hostname=${database_hostname:-"localhost"}
export database_username=${database_username:-"test"}
export database_port=${database_port:-"5432"}
export database_password=${database_password:-"aPassword"}
export database_superusername=${database_superusername:-"test"}
export database_superuserpassword=${database_superuserpassword:-"aPassword"}

export rmq_host=${rmq_host:-"localhost"}
export rmq_user=${rmq_user:-"guest"}
export rmq_password=${rmq_password:-"guest"}
export rmq_virtual_host=${rmq_virtual_host:-"/"}

export elasticSearchHostname=${elasticSearchHostname:-"localhost"}
export elasticsearch_urls=${elasticsearch_urls:-"http://localhost:9200"}

git submodule update --init --recursive

if [[ ! "$(type -p lessc)" ]]; then
    printf "\e[0;32mlessc not found! less must be installed and lessc on your path to build socorro.\e[0m\n" && exit 1
fi

if [ ! -d "$VIRTUAL_ENV" ]; then
    virtualenv -p python2.6 ${VIRTUAL_ENV}
fi
source "$VIRTUAL_ENV/bin/activate"

# install dev + prod dependencies
${VIRTUAL_ENV}/bin/pip install tools/peep-1.2.tar.gz
${VIRTUAL_ENV}/bin/peep install --download-cache=./pip-cache -r requirements.txt

# bootstrap webapp
pushd webapp-django
./bin/bootstrap.sh
popd

# pull pre-built, known version of breakpad
wget --quiet 'https://ci.mozilla.org/job/breakpad/lastSuccessfulBuild/artifact/breakpad.tar.gz'
tar -zxf breakpad.tar.gz
mv breakpad stackwalk
# Build JSON stackwalker
# Depends on breakpad, run "make breakpad" if you don't have it yet
pushd minidump-stackwalk
make
popd
cp minidump-stackwalk/stackwalker stackwalk/bin
