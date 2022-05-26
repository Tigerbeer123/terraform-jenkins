data "template_file" "default_nginx_test" {
  template = file("${path.module}/nginx.tpl")

  vars = {
    domain = huaweicloud_vpc_eip.eip.address
  }
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
  security_group_ids = ["db64e819-6a3a-4c1f-9cad-7e055ec6c0da"]
  availability_zone  = data.huaweicloud_availability_zones.zones.names[0]
  network {
    uuid = "1eb61a05-a313-46e6-8119-f72a715f8254"
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

resource "null_resource" "provision" {
  depends_on = [huaweicloud_compute_eip_associate.associated]

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
    type     = "ssh"
    user     = "root"
    password = var.ecs_password
    host        = huaweicloud_vpc_eip.eip.address
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-jenkins.sh",
      "/tmp/install-jenkins.sh",
          ]
  }
}

