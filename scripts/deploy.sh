#!/usr/bin/env bash

#source onco-ci/scripts/common-utils.sh
#load_modules -ttv2

# http://ghe-rss.roche.com/pages/Oncology-ctDNA/Docs/development/release_management/#build-and-deploy-debian-packages-with-maven
chmod -R g-s .

# Make special arrangements for the longitudinal-analysis repo
PWD_BASENAME=`basename $(pwd)`
if [[ "$PWD_BASENAME" == *"longitudinal-analysis"* ]]
then {
  module load go/go-1.11.4
  make
  mv bin aveniosam_binaries
  backup_artifact `pwd`/aveniosam_binaries $BUILD_ARCHIVE_DIR/$BUILD_TAG
}
else {
  mvn clean deploy -U -Dprod -Dmaven.test.skip
}
fi
