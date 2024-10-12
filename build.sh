#!/bin/bash
#
# Build pipeline script - add to your code execution platform of choice
#

# get configuration statements from build.conf
source ./build.conf


####### FUNCTIONS ######

# Checks that the system has the correct binaries, files, and prerequistes
# requires: nothing,  returns: nothing
# non-zero exit code on failure
precheck_requirements ()
{ 
	# check for required utilities
	for i in docker sed git ssh ssh-agent ssh-add envsubst curl jq ; 
	do
		if [ -z `which $i` ] ; then
			echo "Error: required cli utility $i is missing" >&2
			exit 1
		fi
	done
	
	if [ ! -e "build.conf" -a  ! -e "$SSHKEY" -a ! -e "$DOCKERFILETEMPLATE" ] ; then
		echo "Error: A needed file, build.conf, $DOCKERFILETEMPLATE, or the ssh key, can't be found" >&2
		exit 1
	fi
	
	echo "System utility dependency check completed successfully"
}


# Does the git stuff - auth, then checks the remote repo for updates 
# requires: nothing,  returns nothing
# exits with non-zero value on inability to contact the remote repo
download_latest_code ()
{
  local origdir="`pwd`"
  
  mkdir -p "$LOCALWORKINGPATH"
  cd $LOCALGITREPOPATH
  
  # setup authentication
  echo "Configuring ssh key authentication to github"
  kill -9 $SSH_AGENT_PID
  eval `ssh-agent`
  if [ -z "`echo $SSH_AGENT_PID`" ] ; then
  	echo "Error: Unable to get ssh-agent to run" >&2
  	cd "$origdir"
	  kill -9 $SSH_AGENT_PID
 	  unset SSH_AUTH_SOCK
 	  unset SSH_AGENT_PID
		exit 1
  fi
  ssh-add "$SSHKEY"
  if [ ! $? -eq 0 ] ; then
    echo "Warning: There may have been an issue adding your key to ssh-agent" >&2
  fi
  
  # test authentication to github
  echo "Testing our ability to connect to github..."
  ssh -T -oBatchMode=yes git@github.com
  errno=$?
  if [ $errno -eq 255 ] ; then
    echo "Error: Authentication issue connecting to $GITREPOSSH" >&2
    cd "$origdir"
    kill -9 $SSH_AGENT_PID
  	unset SSH_AUTH_SOCK
 		unset SSH_AGENT_PID
    exit 1
  fi
 
  
  # Actually download changes. To save (a lot) of time it checks for the
  # existing repo folder and just updates that if it exists
  if [ -d "$LOCALGITREPOPATH" ] ; then
    echo "Updating the existing local git repository"
    # clear local changes
    git reset
    git checkout .
    git clean -fdx
    
    cd "$LOCALGITREPOPATH"
    git pull "$GITREPOSSH" "$GITREPOBRANCH"
    if [ $? -ne 0 ] ; then
      echo "Warning: git pull returned a non-successful exit code" >&2
    fi
    cd "$LOCALWORKINGPATH"
  else
    echo "Cloning the github repository"
    git clone --single-branch --branch "$GITREPOBRANCH" "$GITREPOSSH"
    if [ $? -ne 0 ] ; then
      echo "Warning: git clone returned a non-successful exit code" >&2
    fi
  fi
  
  # clean up
  cd "$origdir"
  kill -9 $SSH_AGENT_PID
  unset SSH_AUTH_SOCK
  unset SSH_AGENT_PID
}

# This function creates a _single_ generic dockerfile from a template
# using envsubstr. Variables are in dollarsign curlybracket format
# It's intended to be called from another function
# requires: service subfolder name, latest alpine linux version
# returns: error status (0/1)
generate_default_dockerfile ()
{
  local svcfold=`sed 's/^\.\///g' <<< "$1"`  #removes leading ./
  local alpinever="$2"
  
  if [ -z "$1" -o ! -d "$LOCALGITREPOPATH/$svcfold" ] ; then
    echo "Error: generate_default_dockerfile requires a valid subfolder" >&2
    return 1
  fi
  if [ -z "$2" ] ; then 
  	echo "Error: The alpine linux version is blank or undefined" >&2
  	return 1
  fi
  if [ ! -e "./$DOCKERFILETEMPLATE" ] ; then
    echo "Error: generate_default_dockerfile can't find the Dockerfile template, $DOCKERFILETEMPLATE. The cwd `pwd` might be misset" 2>&1
    exit 1
  fi
  
  echo "Generating a Dockerfile for the service in folder $svcfold"
  
  #check for index.js and package.json
  for i in index.js package.json ; do
    if [ ! -e "$LOCALGITREPOPATH/$svcfold/$i" ] ; then
      echo "Warning: A needed file ($i) is missing in $svcfold!" >&2
      return 1
    fi
  done
  
  # 
  
  #generate Dockerfile from template
  export SVC_FOLDER="$svcfold"
  export ALPINE_VER="$alpinever"  #we only want to look it up once
  cat $DOCKERFILETEMPLATE | envsubst > "$LOCALGITREPOPATH/$svcfold/Dockerfile"
  echo "Dockerfile generated and output to $LOCALGITREPOPATH/$svcfold/Dockerfile"
  
  return 0
}

# this function builds a docker image tagged with the latest commit id
# which is saved to the latest image id
# requires: service folder name

build_container ()
{
  local svcfold=`sed 's/^\.\///g' <<< "$1"`  #removes leading ./
  local svcname=`sed 's/_//g' <<< "$svcfold"`   #removes _ from folder name
	local lastcommit=""
  local origdir="`pwd`"
  
  cd "$LOCALGITREPOPATH/$svcfold"
  lastcommit="`git rev-parse --short HEAD `"
  
  echo "Building container image for $svcfold based on commit $lastcommit"
  
  if [ ! -e "./Dockerfile" ] ; then
    echo "Error: No Dockerfile found in $svcfold, skipping" >&2
    cd "$origdir"
    return 1
  fi
  
  #check docker's connection to docker.io and build
  docker build -t $svcname:$lastcommit ./
  if [ $? -ne 0 ] ; then
    echo "Error: Your docker can't be run. If you're running a rootless docker install then your user needs to be a member of the docker group (`id`)." >&2
    cd "$origdir"
    exit 1
  else
    echo "Your new container image is $svcname:$lastcommit"
    docker image ls | grep "$svcname" | grep "$lastcommit"
  fi
  
  cd "$origdir"
  return 0
}


# Figures out what the latest version of the alpine image is so we can use versions instead of latest
# requires: nothing,  returns: a string, answer is not provided on stdio
find_latest_alpine_version () 
{
	echo $(curl -s "https://registry.hub.docker.com/v2/namespaces/library/repositories/alpine/tags?page=1" | jq | grep -v username | grep name | awk '{print $2}' | grep "[0-9.]" | sed 's/[\",]//g' | head -2 | tail -1 | awk '{print $1}')
}

# This is a wrapper function that enumerates subfolders in the local repo,
# generates a Dockerfile, then creates an image (which is saved locally)
build_all_service_containers () 
{
  local svc=""
  local latestalpine="`find_latest_alpine_version`"
  
  if [ -z "$LOCALGITREPOPATH" ] ; then
    echo "Error: LOCALGITREPOPATH is empty, can't build service containers" >&2
    exit 1
  fi
  
  #enumerate through subfolders in $LOCALGITREPOPATH
  for svc in $( find "$LOCALGITREPOPATH/" -maxdepth 1 -type d | awk -F \/ '{print $NF}' | grep -v -e ^\\. -e ^$ ) ; 
  do
    echo "Found service folder $svc"
    
    generate_default_dockerfile "$svc" "$latestalpine"
    if [ $? -ne 0 ] ; then
      echo "Warning: Service $svc generated an error when creating a Dockerfile" >&2
    fi

    build_container "$svc"
    
  done
}



###### MAIN ######
echo "Build pipeline execution initializing"
echo
precheck_requirements
download_latest_code
build_all_service_containers
echo
echo "Build pipeline execution complete"
