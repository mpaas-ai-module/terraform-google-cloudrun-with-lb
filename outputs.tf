# Outputs (additive — upstream + prior fork had none). Enable DAG wiring of the
# service URL / LB IP / cert to downstream consumers via module_catalog.go.

output "service_url" {
  description = "The Cloud Run service URL."
  value       = google_cloud_run_service.default.status[0].url
}

output "lb_ip" {
  description = "The load balancer frontend IP (external for external LB, internal otherwise)."
  value       = local.is_external ? google_compute_global_address.external_ip[0].address : google_compute_address.internal_ip[0].address
}

output "ssl_certificate_id" {
  description = "The id of the created LB SSL certificate."
  value       = local.is_external ? google_compute_ssl_certificate.external_ssl[0].id : google_compute_region_ssl_certificate.internal_ssl[0].id
}
