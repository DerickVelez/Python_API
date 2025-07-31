

terraform {
  backend "s3" {
    bucket = "demoapp-test"
    key    = "terraform/infrastructure.tfstate"
    region = "us-east-1"
    use_lockfile = true
  }
}
# Configure the AWS Provider
provider "aws" {
  region = "us-east-1" # You can change this to your desired region
}

# --------------------------------------------------------------------------------------------------
# VPC (Virtual Private Cloud)
# --------------------------------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "demo-vpc"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# --------------------------------------------------------------------------------------------------
# SUBNETS
# --------------------------------------------------------------------------------------------------

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true # Essential for public subnets

  tags = {
    Name = "demo-public-subnet"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "demo-public-subnet-b"
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "demo-db-subnet-group"
  subnet_ids = [
    aws_subnet.public.id,
    aws_subnet.public_b.id]

  tags = {
    Name = "demo-db-subnet-group"
  }
}


# --------------------------------------------------------------------------------------------------
# INTERNET GATEWAY
# --------------------------------------------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "demo-igw"
  }
}

# --------------------------------------------------------------------------------------------------
# ROUTE TABLE
# --------------------------------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "demo-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}


# --------------------------------------------------------------------------------------------------
# SECURITY GROUP
# --------------------------------------------------------------------------------------------------

resource "aws_security_group" "ecs_task" {
  name        = "demo-ecs-task-sg"
  description = "Allow inbound HTTP traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "demo-ecs-task-sg"
  }
}


resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Allow inbound HTTP traffic"
  vpc_id      = aws_vpc.main.id


  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds_sg"
  }
}


resource "aws_db_instance" "postgres_db" {
  identifier         = "demo-postgres-db"
  engine             = "postgres"
  engine_version     = "17.4"
  instance_class     = "db.t3.micro"
  allocated_storage  = 10
  storage_type       = "gp2"
  db_name            = "demoappdb"
  username           = "postgres_admin"
  password           = "DemoAppSecurePass1!"
  multi_az = false
  publicly_accessible = true
  skip_final_snapshot = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  tags = {
    Name = "demo-postgres-db"
  }

  depends_on = [
  aws_subnet.public_b,
  aws_security_group.rds_sg
]
}

# --------------------------------------------------------------------------------------------------
# ECR (Elastic Container Registry) - PUBLIC
# --------------------------------------------------------------------------------------------------

# This resource creates a PUBLIC ECR repository.
# WARNING: Any image pushed here will be publicly accessible.
resource "aws_ecrpublic_repository" "app" {
  repository_name = "demo-public-app-repo"
  

  # A catalog data block is required for public repositories
  catalog_data {
    about_text        = "Demo public repository"
    operating_systems = ["Linux"]
    usage_text        = "Used for the ECS demo project"
  }
}

# --------------------------------------------------------------------------------------------------
# Cloudwatch
# --------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "ecs_app" {
  name              = "/ecs/demo-app"
  retention_in_days = 7

  tags = {
    Name = "demo-app-log-group"
  }
}

# --------------------------------------------------------------------------------------------------
# ECS (Elastic Container Service)
# --------------------------------------------------------------------------------------------------

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "demo-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "demo-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

 

  container_definitions = jsonencode([
    {
      name      = "demo-app-container"
      image     = aws_ecrpublic_repository.app.repository_uri
      essential = true
      portMappings = [
        
        {
          containerPort = 8000
          hostPort      = 8000
        }
      ]
      environment = [
        {
          name  = "DATABASE_HOST"
          value = aws_db_instance.postgres_db.address
        },
        {
        name = "DB_username"
        value = "dempoappdb"
        },
        { 
          name = "DB_PASSWORD"
          value = "admin"
        },
        {
          name = "DB_NAME"
          value = "DemoAppSecurePass1!"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_app.name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
     
    }
  ])

  depends_on = [aws_cloudwatch_log_group.ecs_app]
}


# ECS Service
resource "aws_ecs_service" "app" {
  name            = "demo-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public.id, aws_subnet.public_b.id]
    security_groups = [aws_security_group.ecs_task.id]
    assign_public_ip = true
  }

  depends_on = [aws_internet_gateway.main]
  
}


# --------------------------------------------------------------------------------------------------
# IAM Role for ECS Task Execution
# --------------------------------------------------------------------------------------------------

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "demo-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

