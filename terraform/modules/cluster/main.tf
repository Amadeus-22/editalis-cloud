# One EC2 instance running k3s (single-node Kubernetes) behind an Application
# Load Balancer. EKS is deliberately not used: its control plane has a fixed
# monthly price that a lab does not need, and k3s is conformant Kubernetes.

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }
}

# --- IAM: the node can be managed through SSM, write backups to one bucket,
# and read one secret. Nothing else. ---

data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.name}-node"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "node" {
  statement {
    sid       = "ListBackupBucket"
    actions   = ["s3:ListBucket"]
    resources = [var.backup_bucket_arn]
  }
  statement {
    sid       = "ReadWriteBackups"
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["${var.backup_bucket_arn}/postgres/*"]
  }
  statement {
    sid       = "ReadDatabaseSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.db_secret_arn]
  }
}

resource "aws_iam_role_policy" "node" {
  name   = "backup-and-db-secret"
  role   = aws_iam_role.node.id
  policy = data.aws_iam_policy_document.node.json
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.name}-node"
  role = aws_iam_role.node.name
}

# --- The node ---

resource "aws_instance" "node" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.node_security_group_id]
  iam_instance_profile        = aws_iam_instance_profile.node.name
  associate_public_ip_address = true # outbound only; the security group admits the load balancer alone
  monitoring                  = true
  ebs_optimized               = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    k3s_version       = var.k3s_version
    ingress_node_port = var.ingress_node_port
  })
  user_data_replace_on_change = true

  tags = { Name = "${var.name}-node" }
}

# --- Load balancer ---

resource "aws_lb" "this" {
  name                       = var.name
  load_balancer_type         = "application"
  internal                   = false
  subnets                    = var.public_subnet_ids
  security_groups            = [var.lb_security_group_id]
  drop_invalid_header_fields = true
  enable_deletion_protection = !var.lab

  access_logs {
    bucket  = var.logs_bucket
    prefix  = "alb"
    enabled = true
  }
}

resource "aws_lb_target_group" "ingress" {
  name     = "${var.name}-ingress"
  vpc_id   = var.vpc_id
  port     = var.ingress_node_port
  protocol = "HTTP"

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group_attachment" "node" {
  target_group_arn = aws_lb_target_group.ingress.arn
  target_id        = aws_instance.node.id
  port             = var.ingress_node_port
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ingress.arn
  }
}
