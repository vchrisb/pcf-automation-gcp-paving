locals {
    subdomains    = ["*.apps", "*.sys", "*.login.sys", "*.uaa.sys"]
}

variable "email" {
  type = "string"
}

resource "local_file" "keyfile" {
    content     = "${var.service_account_key}"
    filename = "keyfile.json"
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = "${tls_private_key.private_key.private_key_pem}"
  email_address   = "${var.email}"
}

resource "acme_certificate" "certificate" {
  account_key_pem           = "${acme_registration.reg.account_key_pem}"
  common_name               = "${var.env_name}.${var.dns_suffix}"
  subject_alternative_names = "${formatlist("%s.${var.env_name}.${var.dns_suffix}", local.subdomains)}"

  dns_challenge {
    provider                  = "gcloud"
    config {
      GCE_PROJECT               = "${var.project}"
      GCE_SERVICE_ACCOUNT_FILE  = "${local_file.keyfile.filename}"
    }
  }
}

output "certificate_domain" {
  value = "${acme_certificate.certificate.certificate_domain}"
}
output "certificate_url" {
  value = "${acme_certificate.certificate.certificate_url}"
}
output "certificate_pem" {
  value = "${acme_certificate.certificate.certificate_pem}"
}
output "certificate_private_key_pem" {
  value = "${acme_certificate.certificate.private_key_pem}"
}
output "certificate_issuer_pem" {
  value = "${acme_certificate.certificate.issuer_pem}"
}



module "pas_certs" {
  source = "../modules/certs"

  subdomains    = ["*.apps", "*.sys", "*.login.sys", "*.uaa.sys"]
  env_name      = "${var.env_name}"
  dns_suffix    = "${var.dns_suffix}"
  resource_name = "pas-lbcert"

  ssl_cert           = <<EOF
"${acme_certificate.certificate.certificate_pem}"
"${acme_certificate.certificate.issuer_pem}"
EOF
  ssl_private_key    = "${acme_certificate.certificate.private_key_pem}"
}