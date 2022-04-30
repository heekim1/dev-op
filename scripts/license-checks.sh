#!/usr/bin/env bash

source onco-ci/scripts/common-utils.sh
load_modules -ttv2

git clone --depth 1 git@ghe-rss.roche.com:SW-package-management/otss-ops.git
JAVA_FILES_COUNT=`find . -type f -name "*.java" 2>/dev/null | wc -l | xargs`
if [ $JAVA_FILES_COUNT != 0 ]
then {
  echo " ╦╔═╗╦  ╦╔═╗  ╔╦╗╔═╗╔═╗╔═╗╔╗╔╔╦╗╔═╗╔╗╔╔═╗╦ ╦  ╦═╗╔═╗╔═╗╔═╗╦═╗╔╦╗"
  echo " ║╠═╣╚╗╔╝╠═╣   ║║║╣ ╠═╝║╣ ║║║ ║║║╣ ║║║║  ╚╦╝  ╠╦╝║╣ ╠═╝║ ║╠╦╝ ║ "
  echo "╚╝╩ ╩ ╚╝ ╩ ╩  ═╩╝╚═╝╩  ╚═╝╝╚╝═╩╝╚═╝╝╚╝╚═╝ ╩   ╩╚═╚═╝╩  ╚═╝╩╚═ ╩ "
  echo "Java code found. Executing 'mvn site' for license report"
  mvn site -Dmaven.javadoc.skip=true
}
fi


PY_FILES_COUNT=`find . -type f -name "*.py" 2>/dev/null | wc -l | xargs`
if [ $PY_FILES_COUNT != 0 ]; then {
  echo "╔═╗╦ ╦╔╦╗╦ ╦╔═╗╔╗╔  ╦  ╦╔═╗╔═╗╔╗╔╔═╗╔═╗  ╔═╗╦ ╦╔═╗╔═╗╦╔═"
  echo "╠═╝╚╦╝ ║ ╠═╣║ ║║║║  ║  ║║  ║╣ ║║║╚═╗║╣   ║  ╠═╣║╣ ║  ╠╩╗"
  echo "╩   ╩  ╩ ╩ ╩╚═╝╝╚╝  ╩═╝╩╚═╝╚═╝╝╚╝╚═╝╚═╝  ╚═╝╩ ╩╚═╝╚═╝╩ ╩"
  python3 otss-ops/lib/python/py-license-info -p `pwd`/src/ -r -c -o `pwd`/licensereport.html
  if [ $? -ne 0 ]
  then {
    echo "There's either a GPL license in one or more of the deps or there seems to be an issue where the AST parser is not able to parse Python code because of bad syntax or encoding issues. Exiting with status 1"
    exit 1
  }
  fi
}
fi

backup_artifact `pwd`/licensereport.html $BUILD_ARCHIVE_DIR/$BUILD_TAG

# Backup build logs and job config
backup_logs $JOB_NAME $BUILD_NUMBER $BUILD_ARCHIVE_DIR/$BUILD_TAG
