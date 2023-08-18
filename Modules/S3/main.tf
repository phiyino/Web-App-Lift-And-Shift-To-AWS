# create a bucket
resource "aws_s3_bucket" "vprofilebucket" {
  bucket = "vprofile-v2-artifact"
}

# create acl
resource "aws_s3_bucket_acl" "example" {
  bucket = "${aws_s3_bucket.vprofilebucket.id}"
  acl    = "private"
}

