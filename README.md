Devops take home assignment

This repository contains a build pipeline script, a deployment manifest, and a qa script.

Index
  Quickstart
  The Build pipeline
  The Deployment pipeline
  The QA script
  Architecture & Assumptions

dmaas2908 / letmeinbrotha
  

Quickstart

First edit build.conf to include variables appropriate for your system.

Minikube needs to be running. The nginx module should be installed and I think the driver should be set to docker

minikube enable nginx
minikube enable dns
minkube start --driver docker
alias kubectl='minikube kubectl --'

The build.conf file needs to be edited, the SSH key, the local path to the workspace, and the local path to the local git repo must be set. The path to the SSH key must be the full path /home/username/ and not the globbed version (~username)

Run ./build.sh - it should do everything automatically
Then to deploy the kubernetes stuff, you need to get the image version tag from the output of build.sh (or by running git rev-parse --short HEAD) in the local git repository, then:
terraform init
terraform plan
terraform apply -var version_tag="6 digit hex code"   #the default is latest as an alternative

and the containers should be deployed and start as an end result. I didn't have time to do the network ACL stuff, but I was going to apply an egress filter to service-b using a podSelector as is described in "Learn Kubernetes Security" pg. 86. It's a fairly good book.

Lastly, there is a simple QA script to check all the urls and their status codes.
./qa.sh urls.csv


The build pipeline - build.sh

This script is a straightforward automated build pipeline written in Bash. It's intended to work as a standalone script or imported directly into jenkins. It requires configuring a number of variables in the build.conf file, and comes with a template for a Dockerfile, which is kept in build-template-Dockerfile. The variables in the template are filled in automatically by the build.sh script and do not need to be configured anywhere.

For a folder to have a service built for it, it must have an index.js and package.json file in the root of the git repo.

The build.conf file needs to be customized for each environment, at the least it needs the full path to the ssh key to use with github, the workspace, and the full path that'll come from downloading the remote repository. Since the script is intended to run completely without human intervention it uses the configuration file instead of command line arguments.

Docker images are saved locally, in minikube's image list. It would not require much modification to integrate it with a container image repository. Keep in mind that the deployment manifest will need its imagePullRequest changed as well. This script was written and tested on Linux/amd64 only. It's also configured to use minikube by default in the build.conf file.



The deployment pipeline, all the terraform scripts

As requested I wrote a deployment pipeline in terraform. There's not much you need to know to use this. While there's a couple input variables, the only one that's really important is version_tag which is the short commit id/version tag for the git repo and image (I used the same value for both).

To find the commit id either use "minikube image ls" and find the most recent build or go to the local git repo and run "git rev-parse --short HEAD" to find it. The other variables are a tag prefix that minikube appends to image tags by default, and the imagePullRemote which needs to be changed if a remote repo is used.

Other than that, just enter the terraform folder and use:
terraform init
terraform apply -var version_tag="034aeba"   #in this case


##QA script

Not written yet. I'm planning on having a list of urls, their expected status code and something to grep for in a CSV file, but that's prob fancier than it needs to be.
