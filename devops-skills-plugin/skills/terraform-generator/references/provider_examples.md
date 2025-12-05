# Terraform Provider Examples

## AWS Provider

### Provider Configuration

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"  # Latest: v6.23.0 (Dec 2025)
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = var.project_name
    }
  }
}

# Additional provider for different region
provider "aws" {
  alias  = "us_west"
  region = "us-west-2"
}
```

### Common AWS Resources

```hcl
# EC2 Instance
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.private[0].id

  vpc_security_group_ids = [aws_security_group.web.id]

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  user_data = file("${path.module}/user_data.sh")

  tags = {
    Name = "${var.project_name}-web"
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Subnet
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${var.availability_zones[count.index]}"
  }
}

# Security Group
resource "aws_security_group" "web" {
  name_prefix = "${var.project_name}-web-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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
    Name = "${var.project_name}-web-sg"
  }
}

# S3 Bucket
resource "aws_s3_bucket" "data" {
  bucket = "${var.project_name}-data-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.project_name}-data"
  }
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# RDS Database
resource "aws_db_instance" "main" {
  identifier             = "${var.project_name}-db"
  allocated_storage      = 100
  engine                 = "postgres"
  engine_version         = "14.7"
  instance_class         = var.db_instance_class
  db_name                = var.database_name
  username               = var.db_username
  password               = var.db_password

  vpc_security_group_ids = [aws_security_group.database.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  storage_encrypted      = true
  deletion_protection    = true
  skip_final_snapshot    = false
  final_snapshot_identifier = "${var.project_name}-db-final-snapshot"

  tags = {
    Name = "${var.project_name}-db"
  }
}

# Lambda Function
resource "aws_lambda_function" "processor" {
  filename         = "lambda_function.zip"
  function_name    = "${var.project_name}-processor"
  role            = aws_iam_role.lambda.arn
  handler         = "index.handler"
  source_code_hash = filebase64sha256("lambda_function.zip")
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 512

  environment {
    variables = {
      ENVIRONMENT = var.environment
      TABLE_NAME  = aws_dynamodb_table.main.name
    }
  }

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  tags = {
    Name = "${var.project_name}-processor"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = var.environment == "production"

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
```

## Azure Provider

### Provider Configuration

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }

    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}
```

### Common Azure Resources

```hcl
# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg"
  location = var.location

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = azurerm_resource_group.main.tags
}

# Subnet
resource "azurerm_subnet" "app" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]

  service_endpoints = ["Microsoft.Storage", "Microsoft.Sql"]
}

# Network Security Group
resource "azurerm_network_security_group" "app" {
  name                = "${var.project_name}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = azurerm_resource_group.main.tags
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "app" {
  name                = "${var.project_name}-vm"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.app.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = azurerm_resource_group.main.tags
}

# Storage Account
resource "azurerm_storage_account" "main" {
  name                     = "${var.project_name}storage"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }
  }

  tags = azurerm_resource_group.main.tags
}

# SQL Database
resource "azurerm_mssql_server" "main" {
  name                         = "${var.project_name}-sqlserver"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_mssql_database" "main" {
  name      = "${var.project_name}-db"
  server_id = azurerm_mssql_server.main.id
  sku_name  = "S1"

  tags = azurerm_resource_group.main.tags
}

# App Service
resource "azurerm_service_plan" "main" {
  name                = "${var.project_name}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "P1v2"

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_linux_web_app" "main" {
  name                = "${var.project_name}-app"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    application_stack {
      node_version = "18-lts"
    }

    always_on = true
  }

  app_settings = {
    "WEBSITE_NODE_DEFAULT_VERSION" = "18-lts"
    "ENVIRONMENT"                  = var.environment
  }

  tags = azurerm_resource_group.main.tags
}
```

## Google Cloud Provider

### Provider Configuration

```hcl
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"  # Latest: v7.12.0 - includes ephemeral resources & write-only attributes
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
```

### Common GCP Resources

```hcl
# VPC Network
resource "google_compute_network" "main" {
  name                    = "${var.project_name}-vpc"
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "app" {
  name          = "${var.project_name}-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.main.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/16"
  }
}

# Firewall Rule
resource "google_compute_firewall" "allow_http" {
  name    = "${var.project_name}-allow-http"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

# Compute Instance
resource "google_compute_instance" "web" {
  name         = "${var.project_name}-web"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["web", var.environment]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 20
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.app.id

    access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = file("${path.module}/startup.sh")

  service_account {
    email  = google_service_account.app.email
    scopes = ["cloud-platform"]
  }
}

# Cloud Storage Bucket
resource "google_storage_bucket" "data" {
  name          = "${var.project_id}-${var.project_name}-data"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }
}

# Cloud SQL Instance
resource "google_sql_database_instance" "main" {
  name             = "${var.project_name}-db"
  database_version = "POSTGRES_14"
  region           = var.region

  settings {
    tier              = var.db_tier
    availability_type = "REGIONAL"
    disk_size         = 100
    disk_type         = "PD_SSD"

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 30
      }
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.main.id
    }
  }

  deletion_protection = true
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = "${var.project_name}-gke"
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.main.name
  subnetwork = google_compute_subnetwork.app.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.project_name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count

  autoscaling {
    min_node_count = 1
    max_node_count = 10
  }

  node_config {
    machine_type = var.node_machine_type
    disk_size_gb = 100
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      environment = var.environment
      project     = var.project_name
    }

    tags = ["gke-node", var.environment]
  }
}

# Cloud Function
resource "google_cloudfunctions_function" "processor" {
  name        = "${var.project_name}-processor"
  description = "Process data from storage"
  runtime     = "python311"

  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.functions.name
  source_archive_object = google_storage_bucket_object.function_code.name
  trigger_http          = true
  entry_point           = "process"

  environment_variables = {
    ENVIRONMENT = var.environment
    PROJECT_ID  = var.project_id
  }
}
```

## Kubernetes Provider

### Provider Configuration

```hcl
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_cert)
  token                  = var.cluster_token
}
```

### Common Kubernetes Resources

```hcl
# Namespace
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.namespace

    labels = {
      name        = var.namespace
      environment = var.environment
    }
  }
}

# Deployment
resource "kubernetes_deployment" "app" {
  metadata {
    name      = "${var.app_name}-deployment"
    namespace = kubernetes_namespace.app.metadata[0].name

    labels = {
      app         = var.app_name
      environment = var.environment
    }
  }

  spec {
    replicas = var.replica_count

    selector {
      match_labels = {
        app = var.app_name
      }
    }

    template {
      metadata {
        labels = {
          app         = var.app_name
          environment = var.environment
        }
      }

      spec {
        container {
          name  = var.app_name
          image = "${var.image_repository}:${var.image_tag}"

          port {
            container_port = var.container_port
          }

          env {
            name  = "ENVIRONMENT"
            value = var.environment
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = var.container_port
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = var.container_port
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }
        }
      }
    }
  }
}

# Service
resource "kubernetes_service" "app" {
  metadata {
    name      = "${var.app_name}-service"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    selector = {
      app = var.app_name
    }

    port {
      port        = 80
      target_port = var.container_port
    }

    type = "LoadBalancer"
  }
}

# ConfigMap
resource "kubernetes_config_map" "app" {
  metadata {
    name      = "${var.app_name}-config"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    "config.json" = jsonencode({
      environment = var.environment
      log_level   = var.log_level
    })
  }
}

# Secret
resource "kubernetes_secret" "app" {
  metadata {
    name      = "${var.app_name}-secret"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    database_password = base64encode(var.database_password)
    api_key          = base64encode(var.api_key)
  }

  type = "Opaque"
}

# Ingress
resource "kubernetes_ingress_v1" "app" {
  metadata {
    name      = "${var.app_name}-ingress"
    namespace = kubernetes_namespace.app.metadata[0].name

    annotations = {
      "kubernetes.io/ingress.class"                = "nginx"
      "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/ssl-redirect"  = "true"
    }
  }

  spec {
    tls {
      hosts = [var.domain_name]
      secret_name = "${var.app_name}-tls"
    }

    rule {
      host = var.domain_name

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.app.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

# Horizontal Pod Autoscaler
resource "kubernetes_horizontal_pod_autoscaler_v2" "app" {
  metadata {
    name      = "${var.app_name}-hpa"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.app.metadata[0].name
    }

    min_replicas = 2
    max_replicas = 10

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }
  }
}
```
