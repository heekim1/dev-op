#!/usr/bin/env bash

# Usage:
# ./test.sh [-PIPELINE_TYPE]
# 
# Example: 
# For testing against unified_pipeline_v2.0.x/0.5.0-SATv0.5.0
# simply run: ./test.sh
#
# For testing against TTV2,
# Run: ./test.sh -ttv2
#
# For testing against rebel,
# Run: ./test.sh -rebel

PIPELINE_TYPE=${1:-NA}

source onco-ci/scripts/common-utils.sh
load_modules $PIPELINE_TYPE

# Execute BATS and other Maven tests, if any
echo "╔╦╗╔═╗╦  ╦╔═╗╔╗╔  ╔═╗╦  ╔═╗╔═╗╔╗╔  ╔╦╗╔═╗╔═╗╔╦╗"
echo "║║║╠═╣╚╗╔╝║╣ ║║║  ║  ║  ║╣ ╠═╣║║║   ║ ║╣ ╚═╗ ║ "
echo "╩ ╩╩ ╩ ╚╝ ╚═╝╝╚╝  ╚═╝╩═╝╚═╝╩ ╩╝╚╝   ╩ ╚═╝╚═╝ ╩ "
mvn clean test -Dskip.bdd.tests=true -Dskip.unit.tests=false -Dskip.integration.tests=true
if [ $? -ne 0 ]
then {
  echo "There was an issue running Maven tests. Exiting with status 1"
  exit 1
}
fi

# Copy artifacts for Java repos
backup_artifact `pwd`/target/checkstyle-result.xml $BUILD_ARCHIVE_DIR/$BUILD_TAG
backup_artifact `pwd`/target/checkstyle-checker.xml $BUILD_ARCHIVE_DIR/$BUILD_TAG
backup_artifact `pwd`/target/site/jacoco $BUILD_ARCHIVE_DIR/$BUILD_TAG
backup_artifact `pwd`/target/surefire-reports $BUILD_ARCHIVE_DIR/$BUILD_TAG

# Execute pytest, if applicable, and create code coverage and unit test reports
TESTDIR="`pwd`/test"
PY_FILES_COUNT=`ls -1 $TESTDIR/*.py 2>/dev/null | wc -l`

if [ -d "$TESTDIR" ] && [ $PY_FILES_COUNT != 0 ]
then {
  if [ -x "$(command -v pytest)" ]
  then {
    echo "Found 'test' dir and '.py' files"
    echo "╦═╗╦ ╦╔╗╔  ╔═╗╦ ╦╔╦╗╔═╗╔═╗╔╦╗"
    echo "╠╦╝║ ║║║║  ╠═╝╚╦╝ ║ ║╣ ╚═╗ ║ "
    echo "╩╚═╚═╝╝╚╝  ╩   ╩  ╩ ╚═╝╚═╝ ╩ "
    export PYTHONPATH=`pwd`/src:$PYTHONPATH
    pytest --junitxml=`pwd`/testreport.xml \
           --html=`pwd`/testreport.html \
           --self-contained-html  \
           --cov-report html \
           --cov-report annotate \
           --cov=`pwd`/src `pwd`/test/
    if [ $? -ne 0 ]
    then {
      echo "There was an issue running pytest. Exiting with status 1"
      exit 1
    }
    fi
    mkdir -p `pwd`/badges
    coverage-badge -o `pwd`/badges/codecoverage.svg -f
    backup_artifact `pwd`/testreport.html $BUILD_ARCHIVE_DIR/$BUILD_TAG
    backup_artifact `pwd`/testreport.xml $BUILD_ARCHIVE_DIR/$BUILD_TAG
    backup_artifact `pwd`/htmlcov $BUILD_ARCHIVE_DIR/$BUILD_TAG
    backup_artifact `pwd`/coverage.xml $BUILD_ARCHIVE_DIR/$BUILD_TAG
  } else {
    echo "'pytest' is not installed"
  }
  fi
} else {
  echo "No directory called 'test' for unit tests available or no '.py' files found"
}
fi

# Backup build logs and job config
backup_logs $JOB_NAME $BUILD_NUMBER $BUILD_ARCHIVE_DIR/$BUILD_TAG
