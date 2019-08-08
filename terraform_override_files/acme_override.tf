locals {
    subdomains    = ["*.apps", "*.sys", "*.login.sys", "*.uaa.sys", "*.mesh.apps", "pcf"]
}

variable "email" {
  type = "string"
}

provider "acme" {
  version = "<= 1.1.2"
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

resource "tls_private_key" "pas_private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = "${tls_private_key.pas_private_key.private_key_pem}"
  email_address   = "${var.email}"
}

resource "null_resource" "dns-propagation-wait" {
  provisioner "local-exec" {
    command = "sleep 60"
  }
  triggers {
      sys_domain  = "${module.pas.sys_domain}"
      apps_domain = "${module.pas.apps_domain}"
      tcp_domain  = "${module.pas.tcp_domain}"
      mesh_domain  = "${module.pas.mesh_domain}"
      ops_manager_domain  = "${module.ops_manager.ops_manager_dns}"
    }
} 

## CF certificate

resource "acme_certificate" "pcf-certificate" {
  account_key_pem           = "${acme_registration.reg.account_key_pem}"
  common_name               = "${var.env_name}.${var.dns_suffix}"
  subject_alternative_names = "${formatlist("%s.${var.env_name}.${var.dns_suffix}", local.subdomains)}"
  depends_on                = ["google_dns_record_set.nameserver","null_resource.dns-propagation-wait"]
  dns_challenge {
    provider                  = "gcloud"
    config {
      GCE_PROJECT               = "${var.project}"
      GCE_SERVICE_ACCOUNT       = "${var.service_account_key}"
      GCE_PROPAGATION_TIMEOUT   = "600"
      GCE_POLLING_INTERVAL      = "10"
      GCE_TTL                   = "60"
    }
  }
}

output "ssl_cert" {
  sensitive = true
  value     = <<EOF
${acme_certificate.pcf-certificate.certificate_pem}
${acme_certificate.pcf-certificate.issuer_pem}
EOF
}

output "ssl_private_key" {
  sensitive = true
  value     = "${acme_certificate.pcf-certificate.private_key_pem}"
}

resource "google_compute_ssl_certificate" "certificate" {

  name_prefix = "${var.env_name}-pas-lbcert"
  description = "user provided ssl private key / ssl certificate pair"
  certificate = <<EOF
${acme_certificate.pcf-certificate.certificate_pem}
${acme_certificate.pcf-certificate.issuer_pem}
EOF
  private_key = "${acme_certificate.pcf-certificate.private_key_pem}"

  lifecycle = {
    create_before_destroy = true
  }
}

## update module

module "pas" {
  ssl_certificate   = "${google_compute_ssl_certificate.certificate.self_link}"
  mesh_ssl_certificate   = "${google_compute_ssl_certificate.certificate.self_link}"
}