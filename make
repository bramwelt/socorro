#! /bin/bash -e

case "$1" in
    clean)
        bash scripts/clean.sh
        exit 0
        ;;
    breakpad)
        PREFIX=`pwd`/stackwalk/ SKIP_TAR=1 ./scripts/build-breakpad.sh
        exit 0
        ;;
    json_enhancements_pg_extension)
        bash ./scripts/json-enhancements.sh
        exit 0
        ;;
esac

# The following require environment variables to run.
source scripts/bootstrap.sh

case "$1" in
    test)
        bash scripts/test.sh
        ;;
    install)
        bash scripts/install.sh
        ;;
    ci)
        bash scripts/build.sh
        ;;
    package)
        if [ -z "$CI" ]; then
          bash scripts/analysis.sh
          bash scripts/install.sh
          bash scripts/package.sh
        fi
        ;;
    lint)
        bash scripts/lint.sh
        ;;
    *)
       bash scripts/test.sh
       ;;
esac
