resource "aws_route53_zone" "this" {
  name = var.domain_name

  # Nameservers are assigned once and must never change.
  # Destroying this zone forces a registrar update — prevent it.
  lifecycle {
    prevent_destroy = true
  }

  tags = { Name = var.domain_name }
}
