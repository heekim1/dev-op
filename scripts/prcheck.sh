#!/usr/bin/env bash

#source dev-op/scripts/common-utils.sh
#load_modules -ttv2

# Determine version in pom.xml
pom_version=v`xmllint --xpath '/*[local-name()="project"]/*[local-name()="version"]/text()' pom.xml`
matched=`git tag | grep -w $pom_version`

# Check if version has been bumped
if [ "$matched" == "" ]
then {
  echo "A git tag/release was not found for the current version ($pom_version) in the pom.xml"
  exit 0
} else {
  echo "Version was not bumped in pom.xml and an existing tag/release was found for $pom_version. Please bump the version in pom.xml"
  exit 1
}
fi
