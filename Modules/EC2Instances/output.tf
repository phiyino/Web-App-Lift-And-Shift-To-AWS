output "db01_server" {
    value = aws_instance.db-server 
}
output "mc01_server" {
  value = aws_instance.memcache
}
output "rmq01_server" {
  value = aws_instance.rabbitmq
}
output "app01_server" {
  value = aws_instance.tomcat.id
}