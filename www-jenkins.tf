data "template_file" "default_nginx_test" {
  template = file("${path.module}/nginx.tpl")

  vars = {
    domain = "test"
  }
}

# create a new vpc
resource "huaweicloud_vpc" "vpc" {
  count      = 1
  cidr       = "172.16.0.0/16"
  name       = "${var.template_name}_vpc"
}

resource "huaweicloud_vpc_subnet" "subnet" {
  vpc_id      = huaweicloud_vpc.vpc[0].id
  name        = "${var.template_name}_subnet"
  cidr        = "172.16.10.0/24"
  gateway_ip  = "172.16.10.1"
  primary_dns = "100.125.1.250"
}

# Security Group Resource for Module
resource "huaweicloud_networking_secgroup" "default" {
  name   = "${var.template_name}_sg"
}

# Security Group Rule Resource for Module
# allow ping
resource "huaweicloud_networking_secgroup_rule" "allow_ping" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = huaweicloud_networking_secgroup.default.id
}

# allow all
resource "huaweicloud_networking_secgroup_rule" "allow_all" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = huaweicloud_networking_secgroup.default.id
}

data "huaweicloud_availability_zones" "zones" {}
data "huaweicloud_images_image" "default" {
  name        = "Ubuntu 18.04 server 64bit"
  most_recent = true
}

resource "huaweicloud_compute_instance" "instance" {
  name     = var.ecs_name
  admin_pass = var.ecs_password
  system_disk_type = "SAS"
  system_disk_size = 40
  image_id           = data.huaweicloud_images_image.default.id
  flavor_name           = var.ecs_flavor
  security_group_ids = [huaweicloud_networking_secgroup.default.id]
  availability_zone  = data.huaweicloud_availability_zones.zones.names[0]
  network {
    uuid = huaweicloud_vpc_subnet.subnet.id
  }
  
    provisioner "file" {
    source      = "install-jenkins.sh"
    destination = "/tmp/install-jenkins.sh"
  }

  provisioner "file" {
    source      = "install-plugins.sh"
    destination = "/tmp/install-plugins.sh"
  }

#  provisioner "file" {
#    source      = "plugins.txt"
#    destination = "/tmp/plugins.txt"
#  }

  provisioner "file" {
    source      = "jenkins.yaml"
    destination = "/tmp/jenkins.yaml"
  }

  provisioner "file" {
    content      = data.template_file.default_nginx_test.rendered
    destination = "/tmp/jenkins-nginx-conf"
  }  

  connection {
    user        = "root"
    host        = digitalocean_droplet.www-jenkins.ipv4_address
    type        = "ssh"
    private_key = file(var.pvt_key)
    timeout     = "2m"
    agent       = false
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-jenkins.sh",
      "/tmp/install-jenkins.sh",
          ]
  }
  
}

resource "huaweicloud_vpc_eip" "eip" {
  publicip {
    type = "5_bgp"
  }
  bandwidth {
    name        = format("band-%s", formatdate("YYYYMMDDhhmmss", timestamp()))
    size        = 1
    share_type  = "PER"
    charge_mode = "traffic"
  }
}

resource "huaweicloud_compute_eip_associate" "associated" {
  depends_on = [huaweicloud_vpc_eip.eip,huaweicloud_compute_instance.instance]
  public_ip   = huaweicloud_vpc_eip.eip.address
  instance_id = huaweicloud_compute_instance.instance.id
}

