# This is the variables file. All variables that allow the administrator to customize their deployment
# should be specified here. E.g. if you wish the administrator to set the SSH key, and how many
# instances to deploy etc.

variable "ssh_public_key" {
    type = string
    description = "The public key that corresponds to the private SSH key you would want to use to log into the EC2 instances with, should you need to. Should start like 'ssh-rsa AAAA...'"
}

variable "web_port" {
    type = number
    description = "The port to run the webserver on."
    default = 80
}

variable "aws_region" {
    type = string
    description = "The region to deploy to. E.g. eu-west-2 for London."
    default = "eu-west-2"
}

variable "ami" {
    type = string
    description = "The AMI ID to deploy for the server. This AMI needs to be available in the region specified earlier."
    default = "ami-0015a39e4b7c0966f"
}

variable "docker_image" {
    type = string
    description = "Specify the full name for the docker image. This should include the registry if using a private registry, or your username if using an image from the Docker Hub."
}

variable "asg_name" {
    type = string
    description = "The name to give your auto-scaling group."
}
