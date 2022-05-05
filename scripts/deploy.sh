#!/usr/bin/env bash

#source dev-op/scripts/common-utils.sh
#load_modules -ttv2

# The maven deb package plugin will not work if the SGID permission are set. So be sure to chmod -R g-s ${build_dir} the directory where you are doing your builds.
chmod -R g-s .

mvn clean deploy -U -Dprod -Dmaven.test.skip
