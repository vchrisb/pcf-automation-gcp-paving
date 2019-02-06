output "subnet_mgmt_reserved" {
  value     = "${cidrhost(module.infra.ip_cidr_range, 1)}-${cidrhost(module.infra.ip_cidr_range, 9)}"
}

output "subnet_pas_reserved" {
  value     = "${cidrhost(module.pas.pas_subnet_ip_cidr_range, 1)}-${cidrhost(module.pas.pas_subnet_ip_cidr_range, 9)}"
}

output "subnet_pas_svc_reserved" {
  value     = "${cidrhost(module.pas.services_subnet_ip_cidr_range, 1)}-${cidrhost(module.pas.services_subnet_ip_cidr_range, 9)}"
}