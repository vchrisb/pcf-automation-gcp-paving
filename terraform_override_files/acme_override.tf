locals {
    subdomains    = ["*.apps", "*.sys", "*.login.sys", "*.uaa.sys"]
    mesh_subdomains = ["*.mesh.apps"]
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
    command = "sleep 30"
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

resource "acme_certificate" "pas-certificate" {
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
    }
  }
}

output "ssl_cert" {
  sensitive = true
  value     = <<EOF
${acme_certificate.pas-certificate.certificate_pem}
${acme_certificate.pas-certificate.issuer_pem}
EOF
}

output "ssl_private_key" {
  sensitive = true
  value     = "${acme_certificate.pas-certificate.private_key_pem}"
}

resource "google_compute_ssl_certificate" "certificate" {

  name_prefix = "${var.env_name}-pas-lbcert"
  description = "user provided ssl private key / ssl certificate pair"
  certificate = <<EOF
${acme_certificate.pas-certificate.certificate_pem}
${acme_certificate.pas-certificate.issuer_pem}
EOF
  private_key = "${acme_certificate.pas-certificate.private_key_pem}"

  lifecycle = {
    create_before_destroy = true
  }
}


## CF mesh certificate

resource "acme_certificate" "pas-mesh-certificate" {
  account_key_pem           = "${acme_registration.reg.account_key_pem}"
  common_name               = "mesh.apps.${var.env_name}.${var.dns_suffix}"
  subject_alternative_names = "${formatlist("%s.${var.env_name}.${var.dns_suffix}", local.mesh_subdomains)}"
  depends_on                = ["google_dns_record_set.nameserver","null_resource.dns-propagation-wait"]
  dns_challenge {
    provider                  = "gcloud"
    config {
      GCE_PROJECT               = "${var.project}"
      GCE_SERVICE_ACCOUNT       = "${var.service_account_key}"
      GCE_PROPAGATION_TIMEOUT   = "600"
    }
  }
}

output "mesh_ssl_cert" {
  sensitive = true
  value     = <<EOF
${acme_certificate.pas-mesh-certificate.certificate_pem}
${acme_certificate.pas-mesh-certificate.issuer_pem}
EOF
}

output "mesh_ssl_private_key" {
  sensitive = true
  value     = "${acme_certificate.pas-mesh-certificate.private_key_pem}"
}

resource "google_compute_ssl_certificate" "mesh-certificate" {

  name_prefix = "${var.env_name}-pas-mesh-lbcert"
  description = "user provided ssl private key / ssl certificate pair"
  certificate = <<EOF
${acme_certificate.pas-mesh-certificate.certificate_pem}
${acme_certificate.pas-mesh-certificate.issuer_pem}
EOF
  private_key = "${acme_certificate.pas-mesh-certificate.private_key_pem}"

  lifecycle = {
    create_before_destroy = true
  }
}


### Opsman

resource "acme_certificate" "opsman-certificate" {
  account_key_pem           = "${acme_registration.reg.account_key_pem}"
  common_name               = "${module.ops_manager.ops_manager_dns}"
  depends_on                = ["google_dns_record_set.nameserver","null_resource.dns-propagation-wait"]
  dns_challenge {
    provider                  = "gcloud"
    config {
      GCE_PROJECT               = "${var.project}"
      GCE_SERVICE_ACCOUNT       = "${var.service_account_key}"
      GCE_PROPAGATION_TIMEOUT   = "600"
    }
  }
}

output "opsman_ssl_cert" {
  sensitive = true
  value     = <<EOF
${acme_certificate.opsman-certificate.certificate_pem}
${acme_certificate.opsman-certificate.issuer_pem}
EOF
}

output "opsman_ssl_private_key" {
  sensitive = true
  value     = "${acme_certificate.opsman-certificate.private_key_pem}"
}

## update module

module "pas" {
  ssl_certificate   = "${google_compute_ssl_certificate.certificate.self_link}"
  mesh_ssl_certificate   = "${google_compute_ssl_certificate.mesh-certificate.self_link}"
}