resource "kubernetes_pod" "servicea" {
	metadata {
	  name = "service-a"
	  labels = {
	    app = "service-a"
	  }
	}
	
	spec {
	  container {
	    image = "${var.image_name_prefix}servicea:${var.version_tag}"
	    name = "service-a-container"
	    image_pull_policy = "${var.pullfromremote}"
	    
	    port {
	      container_port = 3000
	    }
	    
	    // uses 640Mi of ram
	    resources {
	      limits = {
	        cpu = "0.5"
	        memory = "750Mi"
	      } 
	      requests = {
	        cpu = "0.5"
	        memory = "725Mi"
	      }
	    }
		}   
	}
}

resource "kubernetes_pod" "serviceb" {
	metadata {
	  name = "service-b"
	  labels = {
	    app = "service-b"
	  }
	}
	
	spec {
	  container {
	    // I'm not sure why when using the minikube docker the image name gets mangled but I dont have time to figure it out
	    image = "${var.image_name_prefix}serviceb:${var.version_tag}"
	    name = "service-b-container"
	    image_pull_policy = "${var.pullfromremote}"
	    
	    port {
	      container_port = 8000
	    }
	    
	    // uses 640Mi of ram
	    resources {
	      limits = {
	        cpu = "0.5"
	        memory = "750Mi"
	      } 
	      requests = {
	        cpu = "0.5"
	        memory = "725Mi"
	      }
	    }
		}   
	}
}

resource "kubernetes_service" "servicea-svc" {
	metadata {
		name = "service-a"
	}
	spec {
		selector = {
			app = "service-a"
		}
		port {
			protocol = "TCP"
			port = 3000
			target_port = 3000
		}
		type = "NodePort"
	}
}

resource "kubernetes_service" "serviceb-svc" {
	metadata {
		name = "service-b"
	}
	spec {
		selector = {
			app = "service-b"
		}
		port {
			protocol = "TCP"
			port = 8000
			target_port = 8000
		}
		type = "NodePort"
	}
}

resource "kubernetes_ingress_v1" "ingress-config" {
  metadata {
    name = "ingress-config"
    annotations = {
      ingress_class_name = "nginx"
      "nginx.ingress.kubernetes.io/rewrite-target" = "/$2"
    }
  }
  spec {
    default_backend {
      service {
        name = "service-a"
        port {
          number = 3000
        }
      }
    }
    rule {
      http {
        path {
          path = "/servicea(/|$)(.*)"
          #path_type = "Prefix"
          backend {
            service {
              name = "service-a"
              port {
                number = 3000
              }
            }
          }
        }
        path {
          path = "/serviceb(/|$)(.*)"
          #path_type = "Prefix"
          backend {
            service {
              name = "service-b"
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
  }
}

