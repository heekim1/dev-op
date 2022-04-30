#!/usr/bin/env bash

# Used for auto-deploying a git tag
#
# Usage:
# ./deploy-tag.sh [-PIPELINE_TYPE]
# 
# Example: 
# For deploying against unified_pipeline_v2.0.x/0.5.0-SATv0.5.0
# simply run: ./deploy-tag.sh
#
# For deploying against TTV2,
# Run: ./deploy-tag.sh -ttv2
#
# For deploying against rebel,
# Run: ./deploy-tag.sh -rebel

PIPELINE_TYPE=${1:-NA}

source onco-ci/scripts/common-utils.sh
load_modules $PIPELINE_TYPE
module load git-lfs

# http://ghe-rss.roche.com/pages/Oncology-ctDNA/Docs/development/release_management/#build-and-deploy-debian-packages-with-maven
chmod -R g-s .

package_name=$(xmllint --xpath '/*[local-name()="project"]/*[local-name()="artifactId"]/text()' pom.xml)
echo "--> Oncology module name : $package_name"
echo "--> Examining tag(s) associated with commit $GIT_COMMIT"

commit_tags=$(git tag -l --points-at HEAD)
if [[ -z "${commit_tags// }" ]]
then
    echo "--> No tags found.  Exiting cleanly."
    exit 0
fi

echo "--> Found tags:"
echo "$commit_tags"

pom_version=$(xmllint --xpath '/*[local-name()="project"]/*[local-name()="version"]/text()' pom.xml)
if [ $? -ne 0 ]
then {
    echo "ERROR: Unable to determine pom_version. Please check pom.xml"
    exit 1
}
fi

echo "--> Version found in pom.xml file : $pom_version"
echo "--> Checking to see if any of the tags match pom version..."
for tag in $commit_tags
do {
    # remove leading "v" (if present)
    tag_strip=${tag#"v"}
    echo "--> Checking $tag_strip"
    if [[ "$pom_version" =~ "$tag_strip" ]]
    then {
    	verified_tag=$tag
    	break
    }
    fi
}  
done

if [[ ! $verified_tag ]]
then {
    echo "--> Version tag does not match pom.xml version.  Aborting build."
    exit 1
}
fi

echo "--> Version tag $verified_tag matches version reported in pom.xml $pom_version"

#http://ghe-rss.roche.com/pages/Oncology-ctDNA/Docs/development/release_management/#build-and-deploy-debian-packages-with-maven
chmod -R g-s .

# development releases are indicated via a dash after the version string:
# http://semver.org/#spec-item-9
if echo $tag | grep -P v*[0-9.]\+-.\+
then {
    echo "--> This is a dev release"
    maven_command="mvn -U clean install -Dpack -Dmaven.test.skip"
} else {
    echo "--> This is a prod release"
    maven_command="mvn -U clean deploy -Dprod -Dmaven.test.skip"
}
fi

curl_command="curl -s -I http://rssregistry.roche.com:8081/artifactory/docker-rss/rsu/debian/$package_name-deb/$pom_version/manifest.json"
echo "--> Poking registry with: $curl_command"

$curl_command | tee | head -n 1 > registry_response.txt

if grep "404 Not Found" registry_response.txt
then {
    echo "--> This is a new build!"
}
elif grep "200 OK" registry_response.txt
then {
    echo "--> Image already exists in registry.  Aborting build."
    exit 1
} else {
    echo "--> Unknown response.  Aborting build."
    exit 1
}
fi

echo "--> PWD is $PWD"
git_lfs_cmd="git lfs pull"
echo "git lfs command: $git_lfs_cmd"
$git_lfs_cmd
echo "--> Maven build command: $maven_command"
$maven_command

# Get caller name
PLC=$(xmllint --xpath '/*[local-name()="project"]/*[local-name()="artifactId"]/text()' pom.xml)
echo "Pipeline Component Name (artifactId in 'pom.xml'): $PLC"

# Get caller version
echo "Pipeline Component Version (version in 'pom.xml'): $pom_version"

# Determine the caller type based on the caller name
caller_id=`determine_caller_type $PLC`

if [ "$caller_id" == "unknown" ]
then {
  echo "Unknown caller ID, ACE is not supported for this caller"
} else {
    ace_prod_command="bash onco-ci/scripts/ace-production-dev.sh $caller_id $pom_version"
    echo "--> ACE-Prod run : $ace_prod_command"
    $ace_prod_command
}
fi

# Backup build logs and job config
backup_logs $JOB_NAME $BUILD_NUMBER $BUILD_ARCHIVE_DIR/$BUILD_TAG
