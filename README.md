This repository contains a build pipeline script, a deployment manifest, and a qa script.

The build pipeline - build.sh

This script is a straightforward automated build pipeline written in Bash. It's intended to work as a standalone script or imported directly into jenkins. It requires configuring a number of variables in the build.conf file, and comes with a template for a Dockerfile, which is kept in build-template-Dockerfile.

For a folder to have a service built for it, it must have an index.js and package.json file in the root of the folder.

The build.conf file needs to be customized for each environment, at the least it needs the full path to the ssh key to use with github, the workspace, and the full path that'll come from downloading the remote repository. Since the script is intended to run completely without human intervention it uses the configuration file instead of command line arguments.

Currently, docker images are saved locally. A repo, authentication, and a docker push statement would be required to integrate it with an image repository.


