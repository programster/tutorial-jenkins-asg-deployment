# This configuration file takes our system further by deploying an autoscaling group to make sure
# that multiple instances of our webserver are always running, and exposing them through a load 
# balancer. One can use the load balancer as the endpoint for SSL connections as well.
# Note, this does not directly use the aws instance defined in server.tf, but creates new instances
# itself. This is to demonstrate two different possible ways to deploy EC2 servers.


# Create the launch configuration, which specifies how the auto scaling group will deploy EC2 
# instances.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_configuration
resource "aws_launch_configuration" "my_launch_configuration" {
    image_id        = var.ami
    instance_type   = "t3a.micro"
    security_groups = [aws_security_group.my_hello_world_security_group.id]
    user_data       = data.template_file.my_template_file.rendered

    # When swapping out instances, launch new ones before destroying old ones so there is no
    # downtime. You may need to plan for this if you have database migrations though.
    lifecycle {
        create_before_destroy = true
    }
}


# Declare our VPC resource, using our default VPC
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
data "aws_vpc" "my_default_vpc" {
    default = true
}


# Declare a subnet reesource, using the subnets from my default VPC
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet_ids
data "aws_subnet_ids" "my_default_subnets" {
    vpc_id = data.aws_vpc.my_default_vpc.id
}

# Create an auto scaling target group for defining where to deploy the EC2 servers to.
# This also defines how we can determine if
# the servers are in a healthy state and need re-deploying.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group
resource "aws_lb_target_group" "my_auto_scaling_target_group" {
    name = "myAutoScalingTargetGroup"
    port = var.web_port
    protocol = "HTTP"
    vpc_id = data.aws_vpc.my_default_vpc.id
    
    health_check {
        path = "/"
        protocol = "HTTP"
        matcher = "200"
        interval = 15
        timeout = 3
        healthy_threshold = 2
        unhealthy_threshold = 2
     }
}

# Create the auto scaling group
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group
resource "aws_autoscaling_group" "my_auto_scaling_group" {
    name = var.asg_name
    launch_configuration = aws_launch_configuration.my_launch_configuration.name
    vpc_zone_identifier = data.aws_subnet_ids.my_default_subnets.ids
    
    target_group_arns = [aws_lb_target_group.my_auto_scaling_target_group.arn]
    
    # ELB health check performs n HTTP request healtcheck that checks webserver is responding
    # with 200 code. IF use "EC2" instead, then just checks EC2 server is up, not that website
    # is running.
    health_check_type = "ELB"
    
    # Specify the minimum and maximum number of EC2 instances to maintain.
    min_size = 2
    max_size = 2
    
    # Specify the tag to give the EC2 servers that the auto scaling group deploys
    tag {
        key = "Name"
        value = "MyAutoscalingGroupEc2Server"
        propagate_at_launch = true
    }
}

# Create a security group for the load balancer to use
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "my_load_balancer_security_group" {
    name = "myLoadBalancer"
    # Allow inbound
    ingress {
        from_port = var.web_port
        to_port = var.web_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    # Allow all outbound requests
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


# Create the load balancer
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb
resource "aws_lb" "my_load_balancer" {
    name = "myHttpLoadBalancer"
    load_balancer_type = "application"
    subnets = data.aws_subnet_ids.my_default_subnets.ids
    security_groups = [aws_security_group.my_load_balancer_security_group.id]
}


# Finally, create a listener on the load balancer so that it listens for http requests.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener
resource "aws_lb_listener" "my_load_balancer_http_listener" {
    load_balancer_arn = aws_lb.my_load_balancer.arn
    port = var.web_port
    protocol = "HTTP"
    
    # By default, return a simple 404 page
    default_action {
        type = "fixed-response"
        
        fixed_response {
            content_type = "text/plain"
            message_body = "404: page not found"
            status_code = 404
        }
    }
}


# Add a rule to the listener, configureing it to forward all (*) requests to the auto scaling
# group servers.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule
resource "aws_lb_listener_rule" "my_load_balancer_listener_rule" {
    listener_arn = aws_lb_listener.my_load_balancer_http_listener.arn
    priority = 100
    
    condition {
        path_pattern {
            values = ["*"]
        } 
    }
    
    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.my_auto_scaling_target_group.arn
    }
}