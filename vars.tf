// building while minikube's docker is enabled leads to some auto-garbled tags by default
variable "image_name_prefix" {
  description = "Prefix to an image tag minikube prepends to images by default"
  type = string
  default = "docker.io/library/"
  nullable = true
}

// I'd rather avoid using "latest" as a tag
variable "version_tag" {
  description = "Hexidecimal image version tag based on the git commit"
	type = string
	default = "latest"
}

variable "pullfromremote" {
  description = "Value for imagePullRemote so it can be set to Never for minikube"
  type = string
  default = "Never"
}
