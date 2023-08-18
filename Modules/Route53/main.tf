# create route 53 hosted zone
resource "aws_route53_zone" "private_hosted_zone" {
  name = "vprofile.in"
  vpc {
    vpc_id = var.vpc_id
  }
}

# create route 53 record
resource "aws_route53_record" "db01_record" {
  zone_id = aws_route53_zone.private_hosted_zone.zone_id
  name    = "db01.vprofile.in"
  type    = "A"
  ttl     = "300"
  records = [var.db01_server.private_ip]
}

resource "aws_route53_record" "mc01_record" {
  zone_id = aws_route53_zone.private_hosted_zone.zone_id
  name    = "mc01.vprofile.in"
  type    = "A"
  ttl     = "300"
  records = [var.mc01_server.private_ip]
}

resource "aws_route53_record" "rmq01_record" {
  zone_id = aws_route53_zone.private_hosted_zone.zone_id
  name    = "rmq01.vprofile.in"
  type    = "A"
  ttl     = "300"
  records = [var.rmq01_server.private_ip]
}