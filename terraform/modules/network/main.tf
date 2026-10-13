# VPC with two public subnets (load balancer and the k3s node) and two private
# subnets (database). No NAT gateway: nothing in the private subnets needs to
# reach the internet, and a NAT gateway is the largest fixed cost of a small VPC.

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.name }
}

# The default security group allows everything inside itself. Close it so that
# only the purpose-built groups below are usable.
resource "aws_default_security_group" "closed" {
  vpc_id = aws_vpc.this.id
}

resource "aws_flow_log" "vpc" {
  vpc_id               = aws_vpc.this.id
  traffic_type         = "REJECT"
  log_destination_type = "s3"
  log_destination      = var.flow_log_bucket_arn
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = var.name }
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[count.index]
  cidr_block        = cidrsubnet(var.cidr, 8, count.index)
  # Instances get a public address only when the instance asks for one.
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.name}-public-${count.index}" }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[count.index]
  cidr_block        = cidrsubnet(var.cidr, 8, count.index + 10)
  tags              = { Name = "${var.name}-private-${count.index}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${var.name}-public" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private subnets keep the VPC's local route only.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-private" }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# --- Security groups: load balancer -> node -> database, nothing else. ---

resource "aws_security_group" "lb" {
  name        = "${var.name}-lb"
  description = "Public HTTPS entry point"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name}-lb" }
}

resource "aws_vpc_security_group_ingress_rule" "lb_https" {
  security_group_id = aws_security_group.lb.id
  description       = "HTTPS from the internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "lb_to_node" {
  security_group_id            = aws_security_group.lb.id
  description                  = "Forward to the ingress port of the node"
  referenced_security_group_id = aws_security_group.node.id
  ip_protocol                  = "tcp"
  from_port                    = var.ingress_node_port
  to_port                      = var.ingress_node_port
}

resource "aws_security_group" "node" {
  name        = "${var.name}-node"
  description = "k3s node"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name}-node" }
}

resource "aws_vpc_security_group_ingress_rule" "node_from_lb" {
  security_group_id            = aws_security_group.node.id
  description                  = "Ingress traffic from the load balancer only"
  referenced_security_group_id = aws_security_group.lb.id
  ip_protocol                  = "tcp"
  from_port                    = var.ingress_node_port
  to_port                      = var.ingress_node_port
}

# No SSH rule: the node is reached through SSM Session Manager.
resource "aws_vpc_security_group_egress_rule" "node_https" {
  security_group_id = aws_security_group.node.id
  description       = "Image pulls, package mirrors, SSM and S3 over HTTPS"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "node_to_db" {
  security_group_id            = aws_security_group.node.id
  description                  = "PostgreSQL"
  referenced_security_group_id = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_security_group" "db" {
  name        = "${var.name}-db"
  description = "PostgreSQL, reachable from the node only"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name}-db" }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_node" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL from the k3s node"
  referenced_security_group_id = aws_security_group.node.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}
