# Utilities for Sonar and Multibranch Pipeline

SONAR_SERVER=http://sonarqube.roche.com

declare -A sonar_scanner_tool=(
    [aoa-germline-subtraction]=mvn
    [genomics-region]=mvn
    [qc-annotation]=mvn
    [ctdna-bc-dedup]=mvn
    [ctdna-monitor]=mvn
    [ctdna-chronos]=mvn
    [ctdna-lane-test]=sonar
    [ctdna-snv-caller]=sonar
    [onco-ngs-utils]=mvn
    [customized-preload-data]=sonar
)


function fatal() {
    echo "$1" && exit 1
}


function get_scanner_tool() {
    echo ${sonar_scanner_tool[${SONAR_PROJECT_KEY}]}
}


function exec_sonar() {
    set +x
    if [[  -n "${CHANGE_ID}" ]]; then
    	# running from PR
        BRANCH_OPTS="-Dsonar.pullrequest.branch=${CHANGE_BRANCH} -Dsonar.pullrequest.key=${CHANGE_ID}"
    elif [[ -n "${BRANCH_NAME}" ]]; then
    	BRANCH_OPTS="-Dsonar.branch.name=${BRANCH_NAME}"
    else
        fatal "ERROR: BRANCH_NAME is undefined"
    fi
    set -x

    # Each repo gets its own sonar cache to avoid cross contamination 
    export SONAR_USER_HOME=~/.sonar-cache/${SONAR_PROJECT_KEY}
    mkdir -p ${SONAR_USER_HOME}
    export SRC_DIR=`pwd`
    echo $SRC_DIR

    if [[ "$(get_scanner_tool)" = "mvn" ]]; then
        sonar_cmd="mvn org.sonarsource.scanner.maven:sonar-maven-plugin:3.9.0.2155:sonar"
    else
        sonar_cmd="docker run --rm -v ${SONAR_USER_HOME}:${SONAR_USER_HOME} -v${SRC_DIR}:${SRC_DIR} \
            rssregistry.roche.com:5001/rsu/apps/sonarsource/sonar-scanner-cli"
    fi

    
    ${sonar_cmd} \
        ${BRANCH_OPTS} \
        -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
        -Dsonar.host.url=${SONAR_SERVER} \
        -Dsonar.login=${SONAR_TOKEN} \
        -Dsonar.sources=${SRC_DIR}/src \
        -Dsonar.tests=${SRC_DIR}/test
}


function exec_unittests() {
    ./onco-ci/scripts/test.sh -ttv2
}


function run_sonar_coverage() {
    exec_unittests
    exec_sonar
}
