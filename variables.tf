variable "template_name" {
  description = "template name"
  default = "jenkins"
  type        = string
}

variable "ecs_name" {
  description = "ecs name"
  default = "jenkins-ecs-618431"
  type        = string
}

variable "ecs_flavor" {
  description = "flavor"
  default = "c6s.4xlarge.2"
  type        = string
}

variable "ecs_password" {
  description = "admin password"
  default  = "Abcd1234"
  type        = string
}

