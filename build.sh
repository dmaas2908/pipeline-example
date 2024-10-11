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
	for i in docker sed git ssh ssh-agent ssh-add envsubst ; 
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
		exit 1
  fi
  ssh-add "$SSHKEY"
  if [ ! $? -eq 0 ] ; then
    echo "Warning: There may have been an issue adding your key to ssh-agent" >&2
  fi
  
  # test authentication to github
  ssh -T -oBatchMode=yes git@github.com
  errno=$?
  if [ $errno -eq 255 ] ; then
    echo "Error: Authentication issue connecting to $GITREPOSSH" >&2
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
  
  # this is important, fixes cwd.
  cd "$origdir"
}

# This function creates a _single_ generic dockerfile from a template
# using envsubstr. Variables are in dollarsign curlybracket format
# It's intended to be called from another function
# requires: service subfolder name, latest alpine linux version
# returns: error status (0/1)
generate_default_dockerfile ()
{
  local svcfold=`sed 's/^\.\///i' <<< "$1"`  #removes leading ./
  local alpinever="$2"
  
  if [ -z "$1" -o ! -d "$LOCALGITREPOPATH/$svcfold" ] ; then
    echo "Error: generate_default_dockerfile requires a valid subfolder" >&2
    return 1
  fi
  if [ -z "$2" ] ; then 
  	echo "Error: The alpine linux version is blank or undef" >&2
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
#build_container ()

###### MAIN ######
precheck_requirements
download_latest_code
#cd $LOCALGITREPOPATH
generate_default_dockerfile service_b "3.20.3"
