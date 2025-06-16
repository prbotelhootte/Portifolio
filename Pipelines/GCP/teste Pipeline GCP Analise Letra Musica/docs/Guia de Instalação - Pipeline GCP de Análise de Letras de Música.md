# Guia de Instalação - Pipeline GCP de Análise de Letras de Música

## Pré-requisitos do Sistema

### Requisitos de Hardware
- **CPU**: Mínimo 2 cores, recomendado 4+ cores
- **RAM**: Mínimo 4GB, recomendado 8GB+
- **Armazenamento**: Mínimo 10GB livres
- **Conexão**: Internet banda larga estável

### Sistemas Operacionais Suportados
- **Linux**: Ubuntu 18.04+, CentOS 7+, Debian 9+
- **macOS**: 10.14 (Mojave) ou superior
- **Windows**: 10 ou superior (com WSL2 recomendado)

## Instalação das Dependências

### 1. Google Cloud SDK

#### Linux/macOS
```bash
# Método 1: Script de instalação automática
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Método 2: Package manager (Ubuntu/Debian)
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
sudo apt-get update && sudo apt-get install google-cloud-cli

# Método 3: Homebrew (macOS)
brew install --cask google-cloud-sdk
```

#### Windows
```powershell
# Baixar e executar o instalador
# https://cloud.google.com/sdk/docs/install#windows

# Ou via Chocolatey
choco install gcloudsdk
```

#### Verificação
```bash
gcloud version
gcloud components list
```

### 2. Terraform (Opcional)

#### Linux/macOS
```bash
# Método 1: Download direto
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Método 2: Package manager
# Ubuntu/Debian
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# macOS
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

#### Windows
```powershell
# Chocolatey
choco install terraform

# Ou download manual do site oficial
```

#### Verificação
```bash
terraform version
```

### 3. Docker

#### Linux
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER
newgrp docker

# CentOS/RHEL
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl start docker
sudo systemctl enable docker
```

#### macOS
```bash
# Homebrew
brew install --cask docker

# Ou download do Docker Desktop
# https://docs.docker.com/desktop/mac/install/
```

#### Windows
```powershell
# Download Docker Desktop
# https://docs.docker.com/desktop/windows/install/

# Ou via Chocolatey
choco install docker-desktop
```

#### Verificação
```bash
docker --version
docker run hello-world
```

### 4. Python 3.11+

#### Linux
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install software-properties-common
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update
sudo apt install python3.11 python3.11-pip python3.11-venv

# CentOS/RHEL
sudo yum install python3.11 python3.11-pip

# Verificar versão
python3.11 --version
```

#### macOS
```bash
# Homebrew
brew install python@3.11

# Verificar versão
python3.11 --version
```

#### Windows
```powershell
# Download do site oficial
# https://www.python.org/downloads/

# Ou via Microsoft Store
# Buscar por "Python 3.11"

# Verificar versão
python --version
```

### 5. Git

#### Linux
```bash
# Ubuntu/Debian
sudo apt-get install git

# CentOS/RHEL
sudo yum install git
```

#### macOS
```bash
# Xcode Command Line Tools
xcode-select --install

# Ou Homebrew
brew install git
```

#### Windows
```powershell
# Download do site oficial
# https://git-scm.com/download/win

# Ou via Chocolatey
choco install git
```

#### Verificação
```bash
git --version
```

## Configuração do Ambiente GCP

### 1. Criação do Projeto

#### Via Console Web
1. Acesse [Google Cloud Console](https://console.cloud.google.com/)
2. Clique em "Select a project" → "New Project"
3. Digite o nome do projeto: `lyrics-analysis-pipeline`
4. Selecione a organização (se aplicável)
5. Clique em "Create"

#### Via gcloud CLI
```bash
# Criar projeto
gcloud projects create lyrics-analysis-pipeline --name="Lyrics Analysis Pipeline"

# Configurar como projeto padrão
gcloud config set project lyrics-analysis-pipeline

# Verificar configuração
gcloud config list
```

### 2. Configuração de Billing

#### Via Console Web
1. Acesse [Billing Console](https://console.cloud.google.com/billing)
2. Selecione ou crie uma conta de billing
3. Vincule ao projeto `lyrics-analysis-pipeline`

#### Via gcloud CLI
```bash
# Listar contas de billing
gcloud billing accounts list

# Vincular ao projeto
gcloud billing projects link lyrics-analysis-pipeline --billing-account=BILLING_ACCOUNT_ID
```

### 3. Autenticação

#### Autenticação de Usuário
```bash
# Login interativo
gcloud auth login

# Configurar credenciais padrão para aplicações
gcloud auth application-default login

# Verificar autenticação
gcloud auth list
```

#### Service Account (Para Produção)
```bash
# Criar service account
gcloud iam service-accounts create lyrics-pipeline-sa \
    --description="Service account for lyrics pipeline" \
    --display-name="Lyrics Pipeline SA"

# Gerar chave
gcloud iam service-accounts keys create ~/lyrics-pipeline-key.json \
    --iam-account=lyrics-pipeline-sa@lyrics-analysis-pipeline.iam.gserviceaccount.com

# Configurar variável de ambiente
export GOOGLE_APPLICATION_CREDENTIALS=~/lyrics-pipeline-key.json
```

### 4. Habilitação de APIs

```bash
# Habilitar todas as APIs necessárias
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    bigquery.googleapis.com \
    storage.googleapis.com \
    logging.googleapis.com \
    scheduler.googleapis.com \
    artifactregistry.googleapis.com \
    iam.googleapis.com

# Verificar APIs habilitadas
gcloud services list --enabled
```

## Download e Configuração do Projeto

### 1. Clone do Repositório

```bash
# Clonar repositório
git clone https://github.com/seu-usuario/lyrics-etl-pipeline.git
cd lyrics-etl-pipeline

# Verificar estrutura
ls -la
```

### 2. Configuração de Variáveis

#### Método 1: Arquivo .env
```bash
# Criar arquivo de configuração
cat > .env << EOF
GCP_PROJECT_ID=lyrics-analysis-pipeline
BQ_DATASET_ID=lyrics_analysis
GCS_BUCKET_NAME=lyrics-analysis-pipeline-data
REGION=us-central1
ENVIRONMENT=dev
EOF

# Carregar variáveis
source .env
```

#### Método 2: Terraform Variables
```bash
# Copiar template
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Editar com seus valores
nano terraform/terraform.tfvars
```

Conteúdo do `terraform.tfvars`:
```hcl
project_id  = "lyrics-analysis-pipeline"
region      = "us-central1"
zone        = "us-central1-a"
environment = "dev"
```

### 3. Instalação de Dependências Python

```bash
# Criar ambiente virtual
python3.11 -m venv venv
source venv/bin/activate  # Linux/macOS
# ou
venv\Scripts\activate     # Windows

# Atualizar pip
pip install --upgrade pip

# Instalar dependências
pip install -r requirements.txt

# Verificar instalação
pip list
```

### 4. Configuração de Permissões

```bash
# Tornar scripts executáveis
chmod +x deploy.sh
chmod +x terraform/deploy-terraform.sh

# Verificar permissões
ls -la *.sh terraform/*.sh
```

## Validação da Instalação

### 1. Teste de Conectividade GCP

```bash
# Testar autenticação
gcloud auth list

# Testar acesso ao projeto
gcloud projects describe $GCP_PROJECT_ID

# Testar APIs
gcloud services list --enabled --filter="name:bigquery OR name:storage OR name:run"
```

### 2. Teste de Dependências Python

```bash
# Ativar ambiente virtual
source venv/bin/activate

# Testar importações principais
python -c "
import pandas as pd
import numpy as np
import nltk
from google.cloud import bigquery, storage
print('✅ Todas as dependências importadas com sucesso')
"
```

### 3. Teste de Docker

```bash
# Testar build local
docker build -t lyrics-etl-test .

# Testar execução
docker run --rm lyrics-etl-test python src/etl_processor.py --help
```

### 4. Teste de Terraform (Se Aplicável)

```bash
cd terraform

# Inicializar
terraform init

# Validar configuração
terraform validate

# Planejar (sem aplicar)
terraform plan
```

## Deploy Inicial

### Opção 1: Deploy Rápido

```bash
# Executar script de deploy
./deploy.sh $GCP_PROJECT_ID $REGION

# Aguardar conclusão (10-15 minutos)
# Verificar logs para possíveis erros
```

### Opção 2: Deploy com Terraform

```bash
cd terraform

# Deploy completo
./deploy-terraform.sh deploy $GCP_PROJECT_ID $REGION dev

# Verificar recursos criados
terraform output
```

## Verificação Pós-Instalação

### 1. Verificar Recursos Criados

```bash
# Cloud Storage
gsutil ls gs://$GCS_BUCKET_NAME

# BigQuery
bq ls $GCP_PROJECT_ID:$BQ_DATASET_ID

# Cloud Run
gcloud run jobs list --region=$REGION

# Cloud Scheduler
gcloud scheduler jobs list --location=$REGION
```

### 2. Teste End-to-End

```bash
# Carregar dados de exemplo
echo '{
  "title": "Test Song",
  "artist": "Test Artist",
  "genre": "Pop",
  "year": 2024,
  "lyrics": "This is a test song with happy lyrics about love and friendship."
}' | gsutil cp - gs://$GCS_BUCKET_NAME/raw-data/test_song.json

# Executar pipeline
gcloud run jobs execute lyrics-etl-pipeline --region=$REGION --wait

# Verificar resultados
bq query --use_legacy_sql=false "
SELECT COUNT(*) as total_songs 
FROM \`$GCP_PROJECT_ID.$BQ_DATASET_ID.raw_lyrics\`
"
```

### 3. Verificar Logs

```bash
# Logs do pipeline
gcloud logs read "resource.type=cloud_run_job" --limit=20

# Logs de erro
gcloud logs read "resource.type=cloud_run_job AND severity>=ERROR" --limit=10
```

## Troubleshooting da Instalação

### Problemas Comuns

#### 1. Erro de Quota/Billing
```
Error: Quota exceeded or billing not enabled
```

**Solução:**
```bash
# Verificar billing
gcloud billing projects describe $GCP_PROJECT_ID

# Verificar quotas
gcloud compute project-info describe --project=$GCP_PROJECT_ID
```

#### 2. Erro de Permissões
```
Error: Permission denied
```

**Solução:**
```bash
# Verificar permissões atuais
gcloud projects get-iam-policy $GCP_PROJECT_ID --flatten="bindings[].members" --filter="bindings.members:user:$(gcloud config get-value account)"

# Adicionar permissões necessárias
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="user:$(gcloud config get-value account)" \
    --role="roles/editor"
```

#### 3. Erro de API Não Habilitada
```
Error: API not enabled
```

**Solução:**
```bash
# Habilitar API específica
gcloud services enable NOME_DA_API.googleapis.com

# Verificar status
gcloud services list --enabled --filter="name:NOME_DA_API"
```

#### 4. Erro de Docker
```
Error: Cannot connect to Docker daemon
```

**Solução:**
```bash
# Linux: Verificar se Docker está rodando
sudo systemctl status docker
sudo systemctl start docker

# Verificar permissões
sudo usermod -aG docker $USER
newgrp docker

# Testar
docker run hello-world
```

#### 5. Erro de Python/Dependências
```
ModuleNotFoundError: No module named 'xxx'
```

**Solução:**
```bash
# Verificar ambiente virtual
which python
which pip

# Reinstalar dependências
pip install -r requirements.txt --force-reinstall

# Verificar versão Python
python --version
```

### Logs de Debug

Para debug detalhado, configure:

```bash
# Habilitar logs verbosos do gcloud
export CLOUDSDK_CORE_VERBOSITY=debug

# Logs detalhados do Terraform
export TF_LOG=DEBUG

# Logs Python
export PYTHONUNBUFFERED=1
export LOG_LEVEL=DEBUG
```

## Próximos Passos

Após a instalação bem-sucedida:

1. **Carregar Dados**: Upload de arquivos de letras para o bucket
2. **Executar Pipeline**: Processamento inicial dos dados
3. **Configurar Dashboards**: Setup do Data Studio/Looker
4. **Agendar Execuções**: Configurar frequência de processamento
5. **Monitorar Sistema**: Configurar alertas e métricas

## Suporte

Se encontrar problemas durante a instalação:

1. **Consulte o VALIDATION_GUIDE.md** para troubleshooting detalhado
2. **Verifique os logs** usando os comandos fornecidos
3. **Abra uma issue** no repositório GitHub com detalhes do erro
4. **Entre em contato** via email de suporte

---

**Tempo estimado de instalação**: 30-60 minutos  
**Nível de dificuldade**: Intermediário  
**Suporte**: Disponível via GitHub Issues

