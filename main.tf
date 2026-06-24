resource "google_project_service" "vpcaccess-api" {
  project = var.project
  service = "vpcaccess.googleapis.com"
}

resource "google_cloud_run_service" "default" {
  name     = var.cloudrun_name
  location = var.cloudrun_location
  project  = var.project
  metadata {
    annotations = {
      "run.googleapis.com/ingress" = var.ingress
    }
  }
  template {
    metadata {
      annotations = {
        # Limit scale up to prevent any cost blow outs!
        "autoscaling.knative.dev/maxScale"        = var.max_scale
        "run.googleapis.com/vpc-access-connector" = var.vpc_connector_self_link
        "run.googleapis.com/vpc-access-egress"    = var.egress_traffic


      }
    }

    spec {
      containers {
        image = var.cloudrun_image
        resources {
          limits = {
            cpu    = var.cloudrun_cpu
            memory = var.cloudrun_memory
          }
        }
      }
    }
  }
  lifecycle {
    ignore_changes = [
      template[0].spec[0].containers[0].env
    ]
  }
}

############################
# LOCALS
############################
locals {
  is_internal = var.lb_type == "internal"
  is_external = var.lb_type == "external"
}

############################
# SERVERLESS NEG (COMMON)
############################
resource "google_compute_region_network_endpoint_group" "neg" {
  name                  = "${var.cloudrun_name}-neg"
  project               = var.project
  region                = "${var.cloudrun_location}"
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_service.default.name
  }
  depends_on = [ google_cloud_run_service.default ]
}

############################
# SSL CERTIFICATES
############################

# External (Global)
data "google_compute_ssl_certificate" "external_ssl" {
  count   = local.is_external ? 1 : 0
  name    = var.existing_ssl_name
  project = var.project
}

# Internal (Regional)
data "google_compute_region_ssl_certificate" "internal_ssl" {
  count   = local.is_internal ? 1 : 0
  name    = var.existing_ssl_name
  project = var.project
  region  = "${var.cloudrun_location}"
}

############################
# BACKEND SERVICE
############################

# External Backend (GLOBAL)
resource "google_compute_backend_service" "external_backend" {
  count                  = local.is_external ? 1 : 0
  name                   = "${var.cloudrun_name}-backend"
  project                = var.project
  protocol               = var.backend_protocol
  load_balancing_scheme  = var.external_lb_scheme
  timeout_sec            = var.backend_timeout

  backend {
    group = google_compute_region_network_endpoint_group.neg.id
    balancing_mode = "UTILIZATION"
    capacity_scaler = var.capacity_scaler
  }

  security_policy = google_compute_security_policy.ext_policy[0].id
}

# Internal Backend (REGIONAL)
resource "google_compute_region_backend_service" "internal_backend" {
  count                  = local.is_internal ? 1 : 0
  name                   = "${var.cloudrun_name}-backend"
  project                = var.project
  region                 = "${var.cloudrun_location}"
  protocol               = var.backend_protocol
  load_balancing_scheme  = var.internal_lb_scheme
  timeout_sec            = var.backend_timeout

  backend {
    group = google_compute_region_network_endpoint_group.neg.id
    balancing_mode = "UTILIZATION"
    capacity_scaler = var.capacity_scaler
  }
}

############################
# URL MAP
############################

# External
resource "google_compute_url_map" "external_url_map" {
  count           = local.is_external ? 1 : 0
  name            = "${var.cloudrun_name}-url-map"
  project         = var.project
  default_service = google_compute_backend_service.external_backend[0].id
}

# Internal
resource "google_compute_region_url_map" "internal_url_map" {
  count           = local.is_internal ? 1 : 0
  name            = "${var.cloudrun_name}-url-map"
  project         = var.project
  region          = "${var.cloudrun_location}"
  default_service = google_compute_region_backend_service.internal_backend[0].id
}

############################
# TARGET HTTPS PROXY
############################

# External
resource "google_compute_target_https_proxy" "external_proxy" {
  count            = local.is_external ? 1 : 0
  name             = "${var.cloudrun_name}-proxy"
  project          = var.project
  url_map          = google_compute_url_map.external_url_map[0].id
  ssl_certificates = [data.google_compute_ssl_certificate.external_ssl[0].self_link]
}

# Internal
resource "google_compute_region_target_https_proxy" "internal_proxy" {
  count            = local.is_internal ? 1 : 0
  name             = "${var.cloudrun_name}-proxy"
  project          = var.project
  region           = "${var.cloudrun_location}"
  url_map          = google_compute_region_url_map.internal_url_map[0].id
  ssl_certificates = [data.google_compute_region_ssl_certificate.internal_ssl[0].self_link]
}

############################
# IP ADDRESS
############################

# External
resource "google_compute_global_address" "external_ip" {
  count        = local.is_external ? 1 : 0
  name         = "${var.cloudrun_name}-ip"
  project      = var.project
  address_type = "EXTERNAL"
}

# Internal
resource "google_compute_address" "internal_ip" {
  count        = local.is_internal ? 1 : 0
  name         = "${var.cloudrun_name}-ip"
  project      = var.project
  region       = "${var.cloudrun_location}"
  address_type = "INTERNAL"
  subnetwork   = var.subnetwork
}

############################
# FORWARDING RULE
############################

# External
resource "google_compute_global_forwarding_rule" "external_fr" {
  count                  = local.is_external ? 1 : 0
  name                   = "${var.cloudrun_name}-fr"
  project                = var.project
  target                 = google_compute_target_https_proxy.external_proxy[0].id
  port_range             = var.global_fw_portrange
  ip_protocol            = var.global_fw_ipprotocol
  load_balancing_scheme  = "EXTERNAL"
  ip_address             = google_compute_global_address.external_ip[0].address
}

# Internal
resource "google_compute_forwarding_rule" "internal_fr" {
  count                  = local.is_internal ? 1 : 0
  name                   = "${var.cloudrun_name}-fr"
  project                = var.project
  region                 = "${var.cloudrun_location}"
  target                 = google_compute_region_target_https_proxy.internal_proxy[0].id
  port_range             = var.global_fw_portrange
  ip_protocol            = var.global_fw_ipprotocol
  load_balancing_scheme  = "INTERNAL_MANAGED"
  network                = var.network
  subnetwork             = var.subnetwork
  ip_address             = google_compute_address.internal_ip[0].address
}

############################
# CLOUD ARMOR (EXTERNAL ONLY)
############################

resource "google_compute_security_policy" "ext_policy" {
  count   = local.is_external ? 1 : 0
  name    = "${var.cloudrun_name}-cloud-policy"
  project = var.project

  # Default deny all
  rule {
    action      = "deny(403)"
    priority    = 2147483647
    description = "default rule"

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }

  # Rule 1000 - Allow IP set 1
  rule {
    action   = "allow"
    preview  = false
    priority = 1000

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = [
          "103.21.244.0/22",
          "103.22.200.0/22",
          "103.31.4.0/22",
          "108.162.192.0/18",
          "141.101.64.0/18",
          "173.245.48.0/20",
          "188.114.96.0/20",
          "190.93.240.0/20",
          "197.234.240.0/22",
          "198.41.128.0/17",
        ]
      }
    }
  }

  # Rule 1001 - Allow IP set 2
  rule {
    action      = "allow"
    description = "rule 2"
    preview     = false
    priority    = 1001

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = [
          "104.16.0.0/13",
          "104.24.0.0/14",
          "131.0.72.0/22",
          "162.158.0.0/15",
          "172.64.0.0/13",
        ]
      }
    }
  }
}