
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

output "ssl_cert" {
  sensitive = true
  value     = <<EOF
"${acme_certificate.certificate.certificate_pem}"
"${acme_certificate.certificate.issuer_pem}"
EOF
}

output "ssl_private_key" {
  sensitive = true
  value     = "${acme_certificate.certificate.private_key_pem}"
}

resource "google_compute_ssl_certificate" "certificate" {

  name_prefix = "${var.env_name}-pas-lbcert"
  description = "user provided ssl private key / ssl certificate pair"
  certificate = <<EOF
"${acme_certificate.certificate.certificate_pem}"
"${acme_certificate.certificate.issuer_pem}"
EOF
  private_key = "${acme_certificate.certificate.private_key_pem}"

  lifecycle = {
    create_before_destroy = true
  }
}


module "pas" {
  ssl_certificate   = "${google_compute_ssl_certificate.certificate.self_link}"
}