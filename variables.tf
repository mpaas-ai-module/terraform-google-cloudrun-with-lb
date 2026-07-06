variable "cloudrun_name" {
  description = "The name of the cloudrun service"
  type        = string
}
variable "cloudrun_location" {
  description = "The location of the cloudrun service"
  type        = string
}
variable "project" {
  description = "The project of the cloudrun service"
  type        = string
}
variable "cloudrun_image" {
  description = "The image for the cloudrun service"
  type        = string
}

variable "cloudrun_cpu" {
  description = "Amt of cpu for the cloudrun - service "
  type        = string
  default     = "1000m"
}
variable "cloudrun_memory" {
  description = "Amt of memory for the cloudrun - service"
  type        = string
  default     = "512M"
}

variable "max_scale" {
  description = "No. of parallel srvs to which scaling is done"
  type        = string
}
variable "egress_traffic" {
  description = "Allowed egress for the connector.Can be either of private-ranges-only and all-traffic."
  type        = string
  default = "private-ranges-only"
}

variable "vpc_connector_self_link" {
  type        = string
  description = "The self link of host project vpc connector"
}

# -----------------------------
# SSL CERTIFICATE (created from cert/key files in a platform GCS bucket)
# -----------------------------
variable "ssl_bucket" {
  type        = string
  description = "Name of the GCS bucket holding the TLS certificate and private key files."
}

variable "ssl_certificate_name" {
  type        = string
  description = "Name to give the LB SSL certificate resource created from the bucket files."
}

variable "ssl_cert_object" {
  type        = string
  description = "Path/glob of the certificate (.crt) object within ssl_bucket."
  default     = "*.crt"
}

variable "ssl_key_object" {
  type        = string
  description = "Path/glob of the private key (.key) object within ssl_bucket."
  default     = "*.key"
}

variable "backend_protocol" {
  type        = string
  description = "Protocol used by the backend service."
  default     = "HTTPS"
}

variable "backend_timeout" {
  type        = number
  description = "Timeout (in seconds) for backend service requests."
  default     = 30
}

variable "global_fw_portrange" {
  type        = number
  description = "Port used by the global forwarding rule."
  default     = 443
}

variable "global_fw_ipprotocol" {
  type        = string
  description = "IP protocol used by the global forwarding rule."
  default     = "TCP"
}
variable "ingress" {
  type        = string
  description = "Controls Cloud Run ingress: choose All, Internal, or internal-and-cloud-load-balancing to allow traffic only from internal networks and external HTTPS load balancers."
  default     = "internal-and-cloud-load-balancing"
}


variable "lb_type" {
  description = "Load balancer type: external or internal"
  type        = string

  validation {
    condition     = contains(["external", "internal"], var.lb_type)
    error_message = "The lb_type value must be either 'external' or 'internal'."
  }
}

# -----------------------------
# INTERNAL LB ONLY
# -----------------------------
variable "network" {
  description = "VPC network self link (required for internal LB)"
  type        = string
  default     = null
}

variable "subnetwork" {
  description = "Subnetwork self link (required for internal LB)"
  type        = string
  default     = null
}

variable "internal_lb_scheme" {
  type        = string
  description = "Type of load balancing scheme for the Global LB (EXTERNAL or INTERNAL)."
  default     = "INTERNAL_MANAGED"
}

variable "external_lb_scheme" {
  type        = string
  description = "Type of load balancing scheme for the Global LB (EXTERNAL or INTERNAL)."
  default     = "EXTERNAL"
}

variable "capacity_scaler" {
  type = number
  description = "capacity scaler"
  default = 1.0
}