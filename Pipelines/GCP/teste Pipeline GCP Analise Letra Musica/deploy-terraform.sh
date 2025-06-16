#!/bin/bash

# Script para deploy usando Terraform
# Pipeline ETL de Análise de Letras de Música

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Verificar dependências
check_dependencies() {
    log "Verificando dependências..."
    
    # Verificar Terraform
    if ! command -v terraform &> /dev/null; then
        error "Terraform não está instalado. Instale em: https://www.terraform.io/downloads.html"
        exit 1
    fi
    
    # Verificar gcloud
    if ! command -v gcloud &> /dev/null; then
        error "gcloud CLI não está instalado. Instale em: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    # Verificar autenticação
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        error "gcloud não está autenticado. Execute: gcloud auth login"
        exit 1
    fi
    
    success "Dependências verificadas"
}

# Configurar projeto
setup_project() {
    local project_id=$1
    
    log "Configurando projeto GCP: ${project_id}"
    
    # Configurar projeto padrão
    gcloud config set project ${project_id}
    
    # Verificar se o projeto existe
    if ! gcloud projects describe ${project_id} &>/dev/null; then
        error "Projeto ${project_id} não encontrado ou sem acesso"
        exit 1
    fi
    
    success "Projeto configurado: ${project_id}"
}

# Inicializar Terraform
init_terraform() {
    log "Inicializando Terraform..."
    
    cd terraform
    
    # Inicializar
    terraform init
    
    # Validar configuração
    terraform validate
    
    success "Terraform inicializado"
}

# Planejar deployment
plan_deployment() {
    log "Criando plano de deployment..."
    
    terraform plan -out=tfplan
    
    success "Plano criado: tfplan"
}

# Aplicar deployment
apply_deployment() {
    log "Aplicando deployment..."
    
    terraform apply tfplan
    
    success "Deployment aplicado"
}

# Construir e fazer push da imagem Docker
build_and_push_image() {
    local project_id=$1
    local region=$2
    local environment=$3
    
    log "Construindo e fazendo push da imagem Docker..."
    
    cd ..
    
    # Configurar Docker para Artifact Registry
    gcloud auth configure-docker ${region}-docker.pkg.dev
    
    # Nome da imagem
    local repo_name="lyrics-etl-${environment}"
    local image_url="${region}-docker.pkg.dev/${project_id}/${repo_name}/lyrics-etl:latest"
    
    # Build da imagem
    docker build -t ${image_url} .
    
    # Push da imagem
    docker push ${image_url}
    
    success "Imagem Docker publicada: ${image_url}"
}

# Atualizar Cloud Run Job com nova imagem
update_cloud_run_job() {
    local project_id=$1
    local region=$2
    local environment=$3
    
    log "Atualizando Cloud Run Job..."
    
    local job_name="lyrics-etl-pipeline-${environment}"
    local repo_name="lyrics-etl-${environment}"
    local image_url="${region}-docker.pkg.dev/${project_id}/${repo_name}/lyrics-etl:latest"
    
    # Atualizar job
    gcloud run jobs update ${job_name} \
        --image=${image_url} \
        --region=${region} \
        --project=${project_id}
    
    success "Cloud Run Job atualizado"
}

# Testar deployment
test_deployment() {
    local project_id=$1
    local region=$2
    local environment=$3
    
    log "Testando deployment..."
    
    local job_name="lyrics-etl-pipeline-${environment}"
    
    # Executar job de teste
    log "Executando job de teste..."
    gcloud run jobs execute ${job_name} \
        --region=${region} \
        --project=${project_id} \
        --wait
    
    success "Teste de deployment concluído"
}

# Mostrar informações do deployment
show_deployment_info() {
    log "Obtendo informações do deployment..."
    
    cd terraform
    
    echo ""
    echo "=== INFORMAÇÕES DO DEPLOYMENT ==="
    terraform output
    echo ""
    
    success "Deployment concluído com sucesso!"
}

# Função principal
main() {
    local action=${1:-"deploy"}
    local project_id=$2
    local region=${3:-"us-central1"}
    local environment=${4:-"dev"}
    
    echo "🚀 Pipeline ETL - Deployment Terraform"
    echo "Ação: ${action}"
    echo "Projeto: ${project_id}"
    echo "Região: ${region}"
    echo "Ambiente: ${environment}"
    echo ""
    
    # Verificar se project_id foi fornecido
    if [[ -z "$project_id" ]]; then
        error "Project ID é obrigatório"
        echo "Uso: $0 <action> <project_id> [region] [environment]"
        echo "Ações: deploy, plan, destroy, build-only"
        exit 1
    fi
    
    # Verificar dependências
    check_dependencies
    
    # Configurar projeto
    setup_project ${project_id}
    
    case $action in
        "deploy")
            init_terraform
            plan_deployment
            apply_deployment
            build_and_push_image ${project_id} ${region} ${environment}
            update_cloud_run_job ${project_id} ${region} ${environment}
            test_deployment ${project_id} ${region} ${environment}
            show_deployment_info
            ;;
        "plan")
            init_terraform
            plan_deployment
            ;;
        "destroy")
            warning "Destruindo infraestrutura..."
            read -p "Tem certeza? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cd terraform
                terraform destroy
                success "Infraestrutura destruída"
            else
                log "Operação cancelada"
            fi
            ;;
        "build-only")
            build_and_push_image ${project_id} ${region} ${environment}
            update_cloud_run_job ${project_id} ${region} ${environment}
            ;;
        *)
            error "Ação inválida: ${action}"
            echo "Ações disponíveis: deploy, plan, destroy, build-only"
            exit 1
            ;;
    esac
}

# Executar função principal
main "$@"

