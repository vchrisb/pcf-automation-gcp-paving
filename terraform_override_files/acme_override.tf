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
