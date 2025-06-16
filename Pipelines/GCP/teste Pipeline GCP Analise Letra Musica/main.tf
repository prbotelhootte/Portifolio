# Configuração de Infraestrutura GCP
# Pipeline de Análise de Letras de Música

# Configurações do Terraform
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

# Variáveis
variable "project_id" {
  description = "ID do projeto GCP"
  type        = string
}

variable "region" {
  description = "Região principal do GCP"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zona do GCP"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Locals
locals {
  project_id = var.project_id
  region     = var.region
  zone       = var.zone
  
  # Nomes dos recursos
  bucket_name = "${var.project_id}-lyrics-data-${var.environment}"
  dataset_id  = "lyrics_analysis_${var.environment}"
  
  # Labels padrão
  common_labels = {
    project     = "lyrics-analysis"
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Provider configuration
provider "google" {
  project = local.project_id
  region  = local.region
  zone    = local.zone
}

provider "google-beta" {
  project = local.project_id
  region  = local.region
  zone    = local.zone
}

# APIs necessárias
resource "google_project_service" "required_apis" {
  for_each = toset([
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "logging.googleapis.com",
    "scheduler.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com"
  ])
  
  project = local.project_id
  service = each.value
  
  disable_on_destroy = false
}

# Cloud Storage Bucket
resource "google_storage_bucket" "lyrics_data" {
  name     = local.bucket_name
  location = local.region
  project  = local.project_id
  
  # Configurações de segurança
  uniform_bucket_level_access = true
  
  # Versionamento
  versioning {
    enabled = true
  }
  
  # Lifecycle rules
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
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
  
  labels = local.common_labels
  
  depends_on = [google_project_service.required_apis]
}

# Diretórios no bucket
resource "google_storage_bucket_object" "bucket_folders" {
  for_each = toset([
    "raw-data/",
    "processed/",
    "models/",
    "temp/"
  ])
  
  name    = each.value
  content = "# Diretório criado pelo Terraform"
  bucket  = google_storage_bucket.lyrics_data.name
}

# BigQuery Dataset
resource "google_bigquery_dataset" "lyrics_analysis" {
  dataset_id  = local.dataset_id
  project     = local.project_id
  location    = local.region
  description = "Dataset para análise de letras de música - ${var.environment}"
  
  # Configurações de acesso
  access {
    role          = "OWNER"
    user_by_email = data.google_client_openid_userinfo.me.email
  }
  
  access {
    role           = "READER"
    special_group  = "projectReaders"
  }
  
  access {
    role           = "WRITER"
    special_group  = "projectWriters"
  }
  
  labels = local.common_labels
  
  depends_on = [google_project_service.required_apis]
}

# Tabelas BigQuery
resource "google_bigquery_table" "raw_lyrics" {
  dataset_id = google_bigquery_dataset.lyrics_analysis.dataset_id
  table_id   = "raw_lyrics"
  project    = local.project_id
  
  description = "Dados brutos de letras de música"
  
  # Particionamento por data
  time_partitioning {
    type  = "DAY"
    field = "created_at"
  }
  
  # Clustering
  clustering = ["artist", "genre"]
  
  schema = jsonencode([
    {
      name = "id"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "title"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "artist"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "album"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "genre"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "year"
      type = "INTEGER"
      mode = "NULLABLE"
    },
    {
      name = "lyrics"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "source"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "created_at"
      type = "TIMESTAMP"
      mode = "NULLABLE"
    },
    {
      name = "file_path"
      type = "STRING"
      mode = "NULLABLE"
    }
  ])
  
  labels = local.common_labels
}

resource "google_bigquery_table" "processed_lyrics" {
  dataset_id = google_bigquery_dataset.lyrics_analysis.dataset_id
  table_id   = "processed_lyrics"
  project    = local.project_id
  
  description = "Letras processadas com métricas NLP"
  
  time_partitioning {
    type  = "DAY"
    field = "processed_at"
  }
  
  clustering = ["artist", "language"]
  
  schema = jsonencode([
    {
      name = "id"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "title"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "artist"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "word_count"
      type = "INTEGER"
      mode = "NULLABLE"
    },
    {
      name = "unique_words"
      type = "INTEGER"
      mode = "NULLABLE"
    },
    {
      name = "avg_word_length"
      type = "FLOAT"
      mode = "NULLABLE"
    },
    {
      name = "readability_score"
      type = "FLOAT"
      mode = "NULLABLE"
    },
    {
      name = "language"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "processed_text"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "tokens"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "processed_at"
      type = "TIMESTAMP"
      mode = "NULLABLE"
    }
  ])
  
  labels = local.common_labels
}

resource "google_bigquery_table" "word_frequency" {
  dataset_id = google_bigquery_dataset.lyrics_analysis.dataset_id
  table_id   = "word_frequency"
  project    = local.project_id
  
  description = "Frequência e análise de palavras por música"
  
  time_partitioning {
    type  = "DAY"
    field = "created_at"
  }
  
  clustering = ["word", "lyrics_id"]
  
  schema = jsonencode([
    {
      name = "lyrics_id"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "word"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "frequency"
      type = "INTEGER"
      mode = "NULLABLE"
    },
    {
      name = "tf_idf"
      type = "FLOAT"
      mode = "NULLABLE"
    },
    {
      name = "pos_tag"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "is_stopword"
      type = "BOOLEAN"
      mode = "NULLABLE"
    },
    {
      name = "created_at"
      type = "TIMESTAMP"
      mode = "NULLABLE"
    }
  ])
  
  labels = local.common_labels
}

resource "google_bigquery_table" "sentiment_analysis" {
  dataset_id = google_bigquery_dataset.lyrics_analysis.dataset_id
  table_id   = "sentiment_analysis"
  project    = local.project_id
  
  description = "Análise de sentimentos das letras"
  
  time_partitioning {
    type  = "DAY"
    field = "analyzed_at"
  }
  
  clustering = ["sentiment_label", "lyrics_id"]
  
  schema = jsonencode([
    {
      name = "lyrics_id"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "sentiment_score"
      type = "FLOAT"
      mode = "NULLABLE"
    },
    {
      name = "sentiment_label"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "confidence"
      type = "FLOAT"
      mode = "NULLABLE"
    },
    {
      name = "positive_words"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "negative_words"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "neutral_words"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "analyzed_at"
      type = "TIMESTAMP"
      mode = "NULLABLE"
    }
  ])
  
  labels = local.common_labels
}

# Service Account para ETL
resource "google_service_account" "etl_service_account" {
  account_id   = "lyrics-etl-sa-${var.environment}"
  display_name = "Lyrics ETL Service Account - ${var.environment}"
  description  = "Service account para pipeline ETL de letras de música"
  project      = local.project_id
  
  depends_on = [google_project_service.required_apis]
}

# IAM bindings para service account
resource "google_project_iam_member" "etl_bigquery_data_editor" {
  project = local.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.etl_service_account.email}"
}

resource "google_project_iam_member" "etl_bigquery_job_user" {
  project = local.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.etl_service_account.email}"
}

resource "google_storage_bucket_iam_member" "etl_storage_admin" {
  bucket = google_storage_bucket.lyrics_data.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.etl_service_account.email}"
}

resource "google_project_iam_member" "etl_logging_writer" {
  project = local.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.etl_service_account.email}"
}

# Artifact Registry para imagens Docker
resource "google_artifact_registry_repository" "lyrics_etl_repo" {
  repository_id = "lyrics-etl-${var.environment}"
  location      = local.region
  format        = "DOCKER"
  description   = "Repositório para imagens do pipeline ETL de letras"
  project       = local.project_id
  
  labels = local.common_labels
  
  depends_on = [google_project_service.required_apis]
}

# Cloud Run Job
resource "google_cloud_run_v2_job" "lyrics_etl_job" {
  name     = "lyrics-etl-pipeline-${var.environment}"
  location = local.region
  project  = local.project_id
  
  template {
    template {
      service_account = google_service_account.etl_service_account.email
      
      containers {
        image = "${local.region}-docker.pkg.dev/${local.project_id}/${google_artifact_registry_repository.lyrics_etl_repo.repository_id}/lyrics-etl:latest"
        
        args = [
          "--project-id=${local.project_id}",
          "--dataset-id=${local.dataset_id}",
          "--bucket-name=${local.bucket_name}"
        ]
        
        env {
          name  = "GCP_PROJECT_ID"
          value = local.project_id
        }
        
        env {
          name  = "BQ_DATASET_ID"
          value = local.dataset_id
        }
        
        env {
          name  = "GCS_BUCKET_NAME"
          value = local.bucket_name
        }
        
        env {
          name  = "ENVIRONMENT"
          value = var.environment
        }
        
        resources {
          limits = {
            cpu    = "1"
            memory = "2Gi"
          }
        }
      }
      
      max_retries = 3
      task_count  = 1
      parallelism = 1
      
      task_timeout = "3600s"
    }
  }
  
  labels = local.common_labels
  
  depends_on = [
    google_project_service.required_apis,
    google_artifact_registry_repository.lyrics_etl_repo
  ]
  
  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].image
    ]
  }
}

# Cloud Scheduler Job
resource "google_cloud_scheduler_job" "etl_daily_schedule" {
  name     = "lyrics-etl-daily-${var.environment}"
  region   = local.region
  project  = local.project_id
  
  description = "Execução diária do pipeline ETL de letras - ${var.environment}"
  schedule    = "0 2 * * *"  # Diariamente às 02:00
  time_zone   = "America/Sao_Paulo"
  
  http_target {
    http_method = "POST"
    uri         = "https://${local.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${local.project_id}/jobs/${google_cloud_run_v2_job.lyrics_etl_job.name}:run"
    
    oauth_token {
      service_account_email = google_service_account.etl_service_account.email
    }
  }
  
  depends_on = [
    google_project_service.required_apis,
    google_cloud_run_v2_job.lyrics_etl_job
  ]
}

# Monitoring - Log-based metrics
resource "google_logging_metric" "etl_errors" {
  name   = "lyrics_etl_errors_${var.environment}"
  filter = "resource.type=\"cloud_run_job\" AND resource.labels.job_name=\"${google_cloud_run_v2_job.lyrics_etl_job.name}\" AND severity>=ERROR"
  
  metric_descriptor {
    metric_kind = "GAUGE"
    value_type  = "INT64"
    display_name = "ETL Pipeline Errors - ${var.environment}"
  }
  
  project = local.project_id
}

resource "google_logging_metric" "etl_success" {
  name   = "lyrics_etl_success_${var.environment}"
  filter = "resource.type=\"cloud_run_job\" AND resource.labels.job_name=\"${google_cloud_run_v2_job.lyrics_etl_job.name}\" AND textPayload:\"Pipeline ETL concluído\""
  
  metric_descriptor {
    metric_kind = "GAUGE"
    value_type  = "INT64"
    display_name = "ETL Pipeline Success - ${var.environment}"
  }
  
  project = local.project_id
}

# Alerting Policy
resource "google_monitoring_alert_policy" "etl_failure_alert" {
  display_name = "ETL Pipeline Failure - ${var.environment}"
  project      = local.project_id
  
  conditions {
    display_name = "ETL job failed"
    
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.etl_errors.name}\""
      duration        = "300s"
      comparison      = "COMPARISON_GREATER_THAN"
      threshold_value = 0
      
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }
  
  combiner = "OR"
  enabled  = true
  
  notification_channels = []  # Adicionar canais de notificação conforme necessário
  
  depends_on = [google_logging_metric.etl_errors]
}

# Data source para obter informações do usuário atual
data "google_client_openid_userinfo" "me" {}

# Outputs
output "project_id" {
  description = "ID do projeto GCP"
  value       = local.project_id
}

output "bucket_name" {
  description = "Nome do bucket Cloud Storage"
  value       = google_storage_bucket.lyrics_data.name
}

output "bucket_url" {
  description = "URL do bucket Cloud Storage"
  value       = google_storage_bucket.lyrics_data.url
}

output "dataset_id" {
  description = "ID do dataset BigQuery"
  value       = google_bigquery_dataset.lyrics_analysis.dataset_id
}

output "dataset_location" {
  description = "Localização do dataset BigQuery"
  value       = google_bigquery_dataset.lyrics_analysis.location
}

output "service_account_email" {
  description = "Email do service account ETL"
  value       = google_service_account.etl_service_account.email
}

output "cloud_run_job_name" {
  description = "Nome do Cloud Run Job"
  value       = google_cloud_run_v2_job.lyrics_etl_job.name
}

output "scheduler_job_name" {
  description = "Nome do Cloud Scheduler Job"
  value       = google_cloud_scheduler_job.etl_daily_schedule.name
}

output "artifact_registry_repo" {
  description = "Repositório Artifact Registry"
  value       = google_artifact_registry_repository.lyrics_etl_repo.name
}

output "docker_image_url" {
  description = "URL base para imagens Docker"
  value       = "${local.region}-docker.pkg.dev/${local.project_id}/${google_artifact_registry_repository.lyrics_etl_repo.repository_id}"
}

