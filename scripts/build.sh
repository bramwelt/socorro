#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Jenkins build script for running tests and packaging build
#
# Inspired by Zamboni
# https://github.com/mozilla/zamboni/blob/master/scripts/build.sh

export MAVEN_HOME=${MAVEN_HOME:-"/opt/maven"}
export JAVA_HOME=${JAVA_HOME:-"/usr/lib/jvm/jre-openjdk/"}

export PATH=$MAVEN_HOME/bin:$JAVA_HOME/bin:$PATH

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

# any failures in this script should cause the build to fail
set -e

# Install Maven
if [ ! -d /opt/maven ]; then
  wget http://apache.arvixe.com/maven/maven-3/3.2.2/binaries/apache-maven-3.2.2-bin.tar.gz
  sudo su -c "tar -zxvf apache-maven-3.2.2-bin.tar.gz -C /opt/ && cd /opt && mv apache-maven-3.2.2 maven"
  rm apache-maven-3.2.2-bin.tar.gz
fi

make clean

# copy default unit test configs
pushd socorro/unittest/config
for file in *.py.dist
do
  cp $file `basename $file .dist`
done
popd

errors=0
while read d
do
  if [ ! -f "$d/__init__.py" ]
  then
    echo "$d is missing an __init__.py file, tests will not run"
    errors=$((errors+1))
  fi
done < <(find socorro/unittest/* -not -name logs -type d)

if [ $errors != 0 ]
then
  exit 1
fi

source scripts/bootstrap.sh
# run unit tests
source scripts/test.sh

# pull pre-built, known version of breakpad
make clean
wget --quiet 'https://ci.mozilla.org/job/breakpad/lastSuccessfulBuild/artifact/breakpad.tar.gz'
tar -zxf breakpad.tar.gz
mv breakpad stackwalk
make stackwalker

# run socorro integration test
echo "Running integration test..."
./scripts/rabbitmq-integration-test.sh --destroy
./scripts/elasticsearch-integration-test.sh

# package socorro.tar.gz for distribution
mkdir builds/
# make the analysis
git submodule update --init socorro-toolbox akela
cd akela && mvn package; cd ../
cd socorro-toolbox && mvn package; cd ../
mkdir -p analysis
rsync socorro-toolbox/target/*.jar analysis/
rsync akela/target/*.jar analysis/
rsync -a socorro-toolbox/src/main/pig/ analysis/
PREFIX=builds/socorro source ./scripts/install.sh
if [ -n $BUILD_NUMBER ]
then
  echo "$BUILD_NUMBER" > builds/socorro/JENKINS_BUILD_NUMBER
fi
tar -C builds --mode 755 --exclude-vcs --owner 0 --group 0 -zcf socorro.tar.gz socorro/
