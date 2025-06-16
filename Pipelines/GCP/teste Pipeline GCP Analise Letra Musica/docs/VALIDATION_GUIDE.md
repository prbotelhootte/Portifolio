# Guia de Validação e Troubleshooting
# Pipeline ETL de Análise de Letras de Música

## Validação dos Scripts de Deploy

### 1. Validação do Script Bash (deploy.sh)

#### Pré-requisitos
- gcloud CLI instalado e configurado
- Docker instalado (para build local)
- Permissões adequadas no projeto GCP

#### Teste de Sintaxe
```bash
# Verificar sintaxe do script
bash -n deploy.sh

# Executar em modo dry-run (se disponível)
bash deploy.sh --dry-run your-project-id
```

#### Validação Passo a Passo
```bash
# 1. Verificar autenticação
gcloud auth list

# 2. Verificar projeto
gcloud config get-value project

# 3. Testar APIs (sem executar o script completo)
gcloud services list --available | grep -E "(bigquery|storage|run|scheduler)"

# 4. Verificar permissões
gcloud projects get-iam-policy your-project-id
```

### 2. Validação do Terraform

#### Verificação de Sintaxe
```bash
cd terraform

# Verificar sintaxe
terraform validate

# Verificar formatação
terraform fmt -check

# Planejar sem aplicar
terraform plan
```

#### Validação de Recursos
```bash
# Verificar se recursos já existem
gcloud storage buckets list | grep lyrics
gcloud bigquery datasets list | grep lyrics
gcloud run jobs list | grep lyrics
```

### 3. Validação do Código Python

#### Testes Unitários
```bash
cd lyrics-etl-pipeline

# Instalar dependências de teste
pip install -r requirements.txt
pip install pytest pytest-cov

# Executar testes
python -m pytest tests/ -v

# Executar com cobertura
python -m pytest tests/ --cov=src --cov-report=html
```

#### Teste de Importações
```bash
# Verificar se todas as dependências estão disponíveis
python -c "
import sys
sys.path.append('src')
from etl_processor import LyricsETLProcessor
print('✅ Importações OK')
"
```

#### Teste de Configuração
```bash
# Verificar configurações
python -c "
import sys
sys.path.append('config')
from config import Config
validation = Config.validate_config()
print(f'Configuração válida: {validation[\"valid\"]}')
if not validation['valid']:
    print(f'Variáveis faltando: {validation[\"missing_variables\"]}')
"
```

## Troubleshooting Comum

### 1. Problemas de Autenticação

#### Erro: "gcloud not authenticated"
```bash
# Solução
gcloud auth login
gcloud auth application-default login
```

#### Erro: "Permission denied"
```bash
# Verificar permissões do usuário
gcloud projects get-iam-policy PROJECT_ID --flatten="bindings[].members" --format="table(bindings.role)" --filter="bindings.members:user:YOUR_EMAIL"

# Adicionar permissões necessárias
gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="user:YOUR_EMAIL" \
    --role="roles/owner"
```

### 2. Problemas com APIs

#### Erro: "API not enabled"
```bash
# Habilitar APIs manualmente
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable bigquery.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable scheduler.googleapis.com
```

#### Verificar status das APIs
```bash
gcloud services list --enabled
```

### 3. Problemas com Cloud Storage

#### Erro: "Bucket already exists"
```bash
# Verificar se bucket existe em outro projeto
gsutil ls -p PROJECT_ID

# Usar nome único
BUCKET_NAME="${PROJECT_ID}-lyrics-data-$(date +%s)"
```

#### Erro: "Access denied to bucket"
```bash
# Verificar permissões do bucket
gsutil iam get gs://BUCKET_NAME

# Adicionar permissões
gsutil iam ch user:YOUR_EMAIL:objectAdmin gs://BUCKET_NAME
```

### 4. Problemas com BigQuery

#### Erro: "Dataset already exists"
```bash
# Verificar datasets existentes
bq ls

# Usar dataset com sufixo
DATASET_ID="lyrics_analysis_$(date +%s)"
```

#### Erro: "Table schema mismatch"
```bash
# Verificar schema atual
bq show PROJECT_ID:DATASET_ID.TABLE_NAME

# Atualizar schema (se compatível)
bq update PROJECT_ID:DATASET_ID.TABLE_NAME schema.json
```

### 5. Problemas com Cloud Run

#### Erro: "Image not found"
```bash
# Verificar se imagem existe
gcloud container images list --repository=gcr.io/PROJECT_ID

# Build manual da imagem
docker build -t gcr.io/PROJECT_ID/lyrics-etl .
docker push gcr.io/PROJECT_ID/lyrics-etl
```

#### Erro: "Service account not found"
```bash
# Verificar service accounts
gcloud iam service-accounts list

# Criar service account manualmente
gcloud iam service-accounts create lyrics-etl-sa \
    --description="Service account for lyrics ETL" \
    --display-name="Lyrics ETL SA"
```

### 6. Problemas com Dependências Python

#### Erro: "Module not found"
```bash
# Verificar instalação
pip list | grep -E "(nltk|sklearn|google-cloud)"

# Reinstalar dependências
pip install -r requirements.txt --force-reinstall
```

#### Erro: "NLTK data not found"
```bash
# Download manual dos dados NLTK
python -c "
import nltk
nltk.download('punkt')
nltk.download('stopwords')
nltk.download('averaged_perceptron_tagger')
nltk.download('vader_lexicon')
"
```

### 7. Problemas de Rede/Conectividade

#### Erro: "Connection timeout"
```bash
# Verificar conectividade
curl -I https://storage.googleapis.com
curl -I https://bigquery.googleapis.com

# Verificar proxy/firewall
echo $HTTP_PROXY
echo $HTTPS_PROXY
```

#### Erro: "DNS resolution failed"
```bash
# Verificar DNS
nslookup storage.googleapis.com
nslookup bigquery.googleapis.com
```

## Validação Pós-Deploy

### 1. Verificar Recursos Criados

#### Cloud Storage
```bash
# Listar buckets
gsutil ls

# Verificar estrutura do bucket
gsutil ls -r gs://BUCKET_NAME/

# Testar upload
echo "test" | gsutil cp - gs://BUCKET_NAME/test.txt
gsutil rm gs://BUCKET_NAME/test.txt
```

#### BigQuery
```bash
# Listar datasets
bq ls

# Verificar tabelas
bq ls PROJECT_ID:DATASET_ID

# Testar query
bq query --use_legacy_sql=false "SELECT 1 as test"
```

#### Cloud Run
```bash
# Listar jobs
gcloud run jobs list

# Verificar configuração
gcloud run jobs describe JOB_NAME --region=REGION

# Testar execução
gcloud run jobs execute JOB_NAME --region=REGION --wait
```

### 2. Verificar Logs

#### Cloud Run Logs
```bash
# Visualizar logs do job
gcloud logs read "resource.type=cloud_run_job" --limit=50

# Logs em tempo real
gcloud logs tail "resource.type=cloud_run_job"
```

#### BigQuery Logs
```bash
# Logs de jobs BigQuery
gcloud logs read "resource.type=bigquery_resource" --limit=20
```

### 3. Testar Pipeline End-to-End

#### Preparar Dados de Teste
```bash
# Criar arquivo de teste
cat > test_song.json << EOF
{
  "title": "Test Song",
  "artist": "Test Artist",
  "album": "Test Album",
  "genre": "Pop",
  "year": 2024,
  "lyrics": "This is a test song with happy lyrics about love and friendship."
}
EOF

# Upload para bucket
gsutil cp test_song.json gs://BUCKET_NAME/raw-data/
```

#### Executar Pipeline
```bash
# Executar job manualmente
gcloud run jobs execute JOB_NAME --region=REGION --wait

# Verificar resultado no BigQuery
bq query --use_legacy_sql=false "
SELECT COUNT(*) as total_records 
FROM \`PROJECT_ID.DATASET_ID.raw_lyrics\`
"
```

### 4. Monitoramento Contínuo

#### Configurar Alertas
```bash
# Verificar métricas
gcloud logging metrics list

# Verificar políticas de alerta
gcloud alpha monitoring policies list
```

#### Dashboard de Monitoramento
```bash
# Acessar Cloud Console
echo "Acesse: https://console.cloud.google.com/monitoring/dashboards"
echo "Projeto: PROJECT_ID"
```

## Checklist de Validação

### ✅ Pré-Deploy
- [ ] gcloud CLI configurado
- [ ] Projeto GCP selecionado
- [ ] Permissões adequadas
- [ ] APIs habilitadas
- [ ] Docker instalado (se necessário)

### ✅ Deploy
- [ ] Script executado sem erros
- [ ] Todos os recursos criados
- [ ] Service accounts configurados
- [ ] Permissões aplicadas
- [ ] Imagem Docker publicada

### ✅ Pós-Deploy
- [ ] Bucket acessível
- [ ] Tabelas BigQuery criadas
- [ ] Cloud Run Job funcional
- [ ] Scheduler configurado
- [ ] Logs visíveis
- [ ] Pipeline testado end-to-end

### ✅ Monitoramento
- [ ] Métricas configuradas
- [ ] Alertas funcionando
- [ ] Dashboard acessível
- [ ] Logs estruturados

## Scripts de Validação Automatizada

### validate_deployment.sh
```bash
#!/bin/bash

PROJECT_ID=$1
REGION=${2:-"us-central1"}
BUCKET_NAME="${PROJECT_ID}-lyrics-data"
DATASET_ID="lyrics_analysis"

echo "🔍 Validando deployment..."

# Verificar bucket
if gsutil ls gs://${BUCKET_NAME} &>/dev/null; then
    echo "✅ Bucket existe: ${BUCKET_NAME}"
else
    echo "❌ Bucket não encontrado: ${BUCKET_NAME}"
fi

# Verificar dataset
if bq ls ${PROJECT_ID}:${DATASET_ID} &>/dev/null; then
    echo "✅ Dataset existe: ${DATASET_ID}"
else
    echo "❌ Dataset não encontrado: ${DATASET_ID}"
fi

# Verificar Cloud Run Job
if gcloud run jobs describe lyrics-etl-pipeline --region=${REGION} &>/dev/null; then
    echo "✅ Cloud Run Job existe"
else
    echo "❌ Cloud Run Job não encontrado"
fi

echo "🔍 Validação concluída"
```

Este guia fornece uma base sólida para validar e solucionar problemas no pipeline ETL de análise de letras de música.

