#! /bin/bash -ex

git submodule update --init --recursive

if [[ ! "$(type -p lessc)" ]]; then
    printf "\e[0;32mlessc not found! less must be installed and lessc on your path to build socorro.\e[0m\n" && exit 1
fi

# install dev + prod dependencies
pip install tools/peep-1.2.tar.gz
peep install --download-cache=./pip-cache -r requirements.txt

# bootstrap webapp
pushd webapp-django
./bin/bootstrap.sh
popd
