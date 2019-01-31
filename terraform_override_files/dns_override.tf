
variable "parent_managed_zone" {
  type = "string"
}

resource "google_dns_record_set" "nameserver" {
  name = "${var.env_name}.${var.dns_suffix}"
  type = "NS"
  ttl  = 300

  managed_zone = "${var.parent_managed_zone}"

  rrdatas = ["${module.infra.dns_zone_name_servers}"]
}