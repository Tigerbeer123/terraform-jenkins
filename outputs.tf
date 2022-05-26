
output "ip" {
  value       = huaweicloud_vpc_eip.eip.address
}

#output "file" {
#value = data.template_file.default_nginx_test.rendered
#}
