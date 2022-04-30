#!/usr/bin/env bash

# Common global variables
BUILD_ARCHIVE_DIR="/sc1/groups/onco/Analysis/Jenkins/archive"
MASTER_JENKINS_NODE="sc1jenkins02.eth.rsshpc1.sc1.science.roche.com"
MASTER_ARCHIVE_BASE_DIR="/var/lib/jenkins/jobs/BFX/jobs/Oncology/jobs"

# Common utilities
# Load Lmod modules
function load_modules() {
  local pl_type=$1

  #Load the appropriate environment modules
  if [ "$pl_type" == "-ttv2" ]
  then {
    module use /sc1/groups/pls-devbfx/modulefiles
    module load onco/onco_dev_env/1.4
    module load Tumor_Tissue_V2/0.1.0-SATv0.5.0
  } elif [ "$pl_type" == "-rebel" ]; then {
    export APPS_DIR=/sc1/apps/spack/v0.5.0
    source /sc1/apps/setup/init.sh
    module load onco/onco_dev_env/1.4
  } elif [ "$pl_type" == "-monitor" ]; then {
    module use /sc1/groups/pls-devbfx/modulefiles
    #module load unified_pipeline_v2.0.x/0.5.0-SATv0.5.0
    module load Tumor_Tissue_V2/0.1.0-SATv0.5.0
    module load nodejs/11.9.0 go
  } elif [ "$pl_type" == "-aveniosamui" ]; then {
    module load nodejs maven/3.5.0-JDK8u92-b14 bats
  } else {
    module use /sc1/groups/pls-devbfx/modulefiles
    module load unified_pipeline_v2.0.x/0.5.0-SATv0.5.0
  }
  fi
}

# Check if a directory exists
function dir_exist() {
  local directory=$1
  echo "Checking whether $directory exists..."
  printf '%60s\n' | tr ' ' -
  if [ ! -d $directory ]
  then {
    mkdir -p $directory
    if [ $? -eq 1 ]; then {
        echo "FATAL: Unable to find or create $directory . Exiting..."
        exit 1
    } else {
       echo "$directory created successfully."
   } 
   fi
  } 
  else {
      echo "$directory exists."
      echo "Contents of $directory are:"
      ls -ltrhad $directory/.
  }
  fi
  echo -e "\n"
}

# Clean exited Docker containers
function clean_exited_containers() {
  local exited_containers=`docker ps -a -q -f status=exited`
  if [ "$exited_containers" != "" ]
  then {
  	echo "Removing exited containers"
  	docker rm -v $exited_containers
  }
  fi
}

# Remove dangling Docker images
function rm_dangling_images() {
  local dangling_images=`docker images -f "dangling=true" -q`
  if [ "$dangling_images" != "" ]
  then {
  	echo "Removing dangling images"
  	docker rmi -f $dangling_images
  }
  fi
}

# Back up build artifacts
function backup_artifact() {
  local artifact=$1
  local archive_dir=$2
  local curr_date=`date +%Y%m%d%H%M`

  if [ -e $artifact ]
  then {
    # Get only artifact basename
    artifact_dir=`dirname $artifact`
    artifact=`basename $artifact`
    # Create the archive dir, if it doesn't exist
    mkdir -p $archive_dir
    # Compress it
    zip -9 -r $artifact.$curr_date.zip $artifact_dir/$artifact
    # Move the compressed artifact
    mv $artifact.$curr_date.zip $archive_dir/.
  }
  fi
}

# Backup build logs
function backup_logs() {
  local job_name=$1
  local build_number=$2
  local backup_dir=$3

  job_name=`basename $job_name`
  local curr_date=`date +%Y%m%d%H%M`

  # Create a temporary directory to store the logs and configs
  mkdir -p ${backup_dir}/configs_and_logs
  # SCP from master's archive to backup dir
  scp -r ${MASTER_JENKINS_NODE}:${MASTER_ARCHIVE_BASE_DIR}/${job_name}/builds/${build_number}/* ${backup_dir}/configs_and_logs
  # Zip the files
  pushd ${backup_dir}
  zip -9 -r configs_and_logs.$curr_date.zip configs_and_logs
  if [ $? -eq 0 ]; then {
    # Remove the temp dir
    rm -rf configs_and_logs
  }
  fi
  popd
}

# Docker-level testing: Install the docker image
function install_docker() {
  echo "Docker image installation"
  mvn -U clean install -Dpack -Dmaven.test.skip
  if [ $? -ne 0 ]; then {
    echo "ERROR: Pipeline component Docker image installation failed. Exiting."
    exit 1
  }
  fi
}

# Docker-level testing: Remove the docker image
function remove_docker() {
  local image_with_tag=$1
  if [[ "$(docker images -q $image_with_tag 2> /dev/null)" != "" ]]; then {
    echo "Removing $image_with_tag to free up disk space"
    docker rmi -f $image_with_tag
    if [ $? -ne 0 ]; then {
      echo "ERROR: Unable to remove $image_with_tag. Exiting."
      exit 1
    }
    fi
  } else {
    echo "No such image: $image_with_tag"
    exit 0
  }
  fi
}

# Docker-level testing: Execute the docker test
function test_plc_docker() {
  local image_with_tag=$1
  local plc_command_file=$2
  echo "Testing $image_with_tag with cmd file: $plc_command_file"
  # Run the command, also set env vars which are loaded from the TTv2 module
  local plc_name=`get_component_name $image_with_tag`
  local plc_version=`get_component_version $image_with_tag`
  local custom_env_file=`pwd`/bfxenvs
  echo "Creating custom environment file: $custom_env_file"
  echo "export CTDNA_TEST_DATA=$CTDNA_TEST_DATA" > $custom_env_file
  echo "export ONCOLOGY_TEST_DATA=$ONCOLOGY_TEST_DATA" >> $custom_env_file
  echo "export ONCO_PROG=$ONCO_PROG" >> $custom_env_file
  echo "export ONCO_INDEXES=$ONCO_INDEXES" >> $custom_env_file
  echo "export PLC_NAME=$plc_name" >> $custom_env_file
  echo "export PLC_VERSION=$plc_version" >> $custom_env_file
  docker run -u $UID --rm \
      -v /sc1:/sc1 -v `pwd`:`pwd` -w `pwd` \
      $image_with_tag bash -c \
      "source /home/analysis/.bashrc; \
       source $custom_env_file; \
       echo Running the caller from within the container; \
       bash -x `pwd`/$plc_command_file || exit 1; \
       if [ $? -ne 0 ]; then exit 1; fi"
  if [ $? -ne 0 ]; then {
    echo "ERROR: Pipeline component test failed for $image_with_tag. Exiting."
    exit 1
  } else {
    echo "Cleaning up custom env file: $custom_env_file"
    rm $custom_env_file
  }
  fi
}

function get_component_name() {
  local image_with_tag=$1 #"$BASE_IMAGE/$COMPONENT_NAME-$USER:$COMPONENT_VERSION"
  local image_name=`echo $image_with_tag | cut -d':' -f 1 | awk -F'/' '{print $NF}'`
  echo ${image_name%-*} # Strip suffix
}

function get_component_version() {
  local image_with_tag=$1 #"$BASE_IMAGE/$COMPONENT_NAME-$USER:$COMPONENT_VERSION"
  echo $image_with_tag | cut -d':' -f 2
}

# prints colored text
function print_style () {
  if [ "$2" == "info" ]; then {
    local color="96m"
  } elif [ "$2" == "success" ]; then {
    local color="92m"
  } elif [ "$2" == "warning" ]; then {
    local color="93m"
  } elif [ "$2" == "danger" ]; then {
    local color="91m"
  } else {
    local color="0m"
  }
  fi

  local startcolor="\e[$color"
  local endcolor="\e[0m"

  printf "$startcolor%b$endcolor" "$1\n"
}


# Determine the caller type based on the caller name
function determine_caller_type() {
  local plc=$1
  local caller_id="unknown"
  case $plc in
    devops-test)
      caller_id="FUSION"
      ;;
    ctdna-copy-number-analysis-cnvkit*)
      caller_id="CNV"
      ;;
    msi-caller)
      caller_id="MSI"
      ;;
    ctdna-snv-caller)
      caller_id="SNV"
      ;;
    ctdna-fusion)
      caller_id="FUSION"
      ;;
    ctdna-indel*)
      caller_id="INDEL"
      ;;
    mnv-caller)
      caller_id="MNV"
      ;;

  esac
  echo $caller_id
}
