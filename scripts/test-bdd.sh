#!/usr/bin/env bash

# Usage:
# ./bdd-tests.sh
#
# Intended for testing against TTV2,
#
# Only applicable for Python-based repos

source onco-ci/scripts/common-utils.sh
load_modules -ttv2

# Run Behave BDD tests, if any
FEATURESDIR=`pwd`/features
FEATURE_FILE_COUNT=`ls -1 $FEATURESDIR/*.feature 2>/dev/null | wc -l`
JAVA_FILE_COUNT=`find . -name "*.java" 2>/dev/null | wc -l`

if [ -d "$FEATURESDIR" ] && [ $FEATURE_FILE_COUNT != 0 ]
then {
	if [ -x "$(command -v behave)" ]
	then {
		# You may also add this option: --junit --junit-directory junit-reports for JUnit reports
		echo "╦═╗╦ ╦╔╗╔╔╗╔╦╔╗╔╔═╗  ╔╗ ╔═╗╦ ╦╔═╗╦  ╦╔═╗"
		echo "╠╦╝║ ║║║║║║║║║║║║ ╦  ╠╩╗║╣ ╠═╣╠═╣╚╗╔╝║╣ "
		echo "╩╚═╚═╝╝╚╝╝╚╝╩╝╚╝╚═╝  ╚═╝╚═╝╩ ╩╩ ╩ ╚╝ ╚═╝"
		export PYTHONPATH=`pwd`/src:$PYTHONPATH
		behave -f allure_behave.formatter:AllureFormatter -o allure-results features
		if [ $? -ne 0 ]
		then {
		  echo "There was an issue running the BDD tests. Exiting with status 1"
		  exit 1
		}
		fi
		backup_artifact `pwd`/allure-results $BUILD_ARCHIVE_DIR/$BUILD_TAG
	} else {
		echo "'behave' is not installed. Not executing BDD tests"
	}
	fi
} elif [ "$JAVA_FILE_COUNT" -ne 0 ] 
	then {
	echo "No 'features' directory available in repo for 'behave' BDD tests or no Gherkin files found"
	echo "Found Java files. Could be a Java repo."
	echo "╔╦╗╔═╗╦  ╦╔═╗╔╗╔  ╔═╗╦  ╔═╗╔═╗╔╗╔  ╔╦╗╔═╗╔═╗╔╦╗"
	echo "║║║╠═╣╚╗╔╝║╣ ║║║  ║  ║  ║╣ ╠═╣║║║   ║ ║╣ ╚═╗ ║ "
	echo "╩ ╩╩ ╩ ╚╝ ╚═╝╝╚╝  ╚═╝╩═╝╚═╝╩ ╩╝╚╝   ╩ ╚═╝╚═╝ ╩ "
	#mvn clean test -Dskip.bdd.tests=false -Dskip.unit.tests=true
	mvn clean test
	if [ $? -ne 0 ]
	then {
	  echo "There was an issue running the BDD tests. Exiting with status 1"
	  exit 1
	}
	fi
	backup_artifact `pwd`/target/cucumber-report $BUILD_ARCHIVE_DIR/$BUILD_TAG
}
fi

# Backup build logs and job config
backup_logs $JOB_NAME $BUILD_NUMBER $BUILD_ARCHIVE_DIR/$BUILD_TAG
