#! /bin/bash -e
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Jenkins build script for running tests and packaging build

source scripts/clean.sh

source scripts/bootstrap.sh

source scripts/test.sh

source scripts/integration-test.sh

# Don't build the package on Travis-CI
if [ -z "$CI" ]; then

  source scripts/analysis.sh

  source scripts/install.sh

  source scripts/package.sh

fi
