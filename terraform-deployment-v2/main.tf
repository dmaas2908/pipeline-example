resource "kubernetes_pod" "pod-definition" {
    for_each = local.services
	metadata {
	  name = each.key
	  labels = {
	    app = each.key
	  }
	}
	
	spec {
	  container {
	    image = "${var.image_name_prefix}${trim(each.key, "-")}:${var.version_tag}"
	    name = "${each.key}-container"
	    image_pull_policy = "${var.pullfromremote}"
	    
	    port {
	      container_port = each.value
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


resource "kubernetes_service" "service-definition" {
    for_each = local.services
    
	metadata {
		name = each.key
	}
	spec {
		selector = {
			app = each.key
		}
		port {
			protocol = "TCP"
			port = each.value
			target_port = each.value
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

