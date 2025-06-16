#!/bin/bash

# Script de deploy para Cloud Run Jobs
# Pipeline ETL de Análise de Letras de Música

set -e

# Configurações
PROJECT_ID=${1:-"your-project-id"}
REGION=${2:-"us-central1"}
SERVICE_NAME="lyrics-etl-pipeline"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"
DATASET_ID="lyrics_analysis"
BUCKET_NAME="${PROJECT_ID}-lyrics-data"

echo "🚀 Iniciando deploy do pipeline ETL..."
echo "Projeto: ${PROJECT_ID}"
echo "Região: ${REGION}"
echo "Imagem: ${IMAGE_NAME}"

# Verificar se gcloud está configurado
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "❌ Erro: gcloud não está autenticado"
    echo "Execute: gcloud auth login"
    exit 1
fi

# Configurar projeto
echo "📋 Configurando projeto..."
gcloud config set project ${PROJECT_ID}

# Habilitar APIs necessárias
echo "🔧 Habilitando APIs do GCP..."
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    bigquery.googleapis.com \
    storage.googleapis.com \
    logging.googleapis.com \
    scheduler.googleapis.com

# Criar bucket se não existir
echo "🪣 Criando bucket Cloud Storage..."
if ! gsutil ls gs://${BUCKET_NAME} &>/dev/null; then
    gsutil mb -p ${PROJECT_ID} -l ${REGION} gs://${BUCKET_NAME}
    echo "✅ Bucket criado: gs://${BUCKET_NAME}"
else
    echo "ℹ️ Bucket já existe: gs://${BUCKET_NAME}"
fi

# Criar estrutura de diretórios no bucket
echo "📁 Criando estrutura de diretórios..."
echo "Estrutura criada" | gsutil cp - gs://${BUCKET_NAME}/raw-data/.keep
echo "Estrutura criada" | gsutil cp - gs://${BUCKET_NAME}/processed/.keep
echo "Estrutura criada" | gsutil cp - gs://${BUCKET_NAME}/models/.keep

# Criar dataset BigQuery
echo "🗄️ Criando dataset BigQuery..."
if ! bq ls -d ${PROJECT_ID}:${DATASET_ID} &>/dev/null; then
    bq mk --dataset \
        --description="Dataset para análise de letras de música" \
        --location=${REGION} \
        ${PROJECT_ID}:${DATASET_ID}
    echo "✅ Dataset criado: ${DATASET_ID}"
else
    echo "ℹ️ Dataset já existe: ${DATASET_ID}"
fi

# Criar tabelas BigQuery
echo "📊 Criando tabelas BigQuery..."
# Substituir variáveis no SQL
sed "s/\${PROJECT_ID}/${PROJECT_ID}/g" sql/create_tables.sql > /tmp/create_tables_processed.sql
bq query --use_legacy_sql=false < /tmp/create_tables_processed.sql
echo "✅ Tabelas criadas no BigQuery"

# Criar service account
echo "🔐 Criando service account..."
SERVICE_ACCOUNT_NAME="lyrics-etl-sa"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if ! gcloud iam service-accounts describe ${SERVICE_ACCOUNT_EMAIL} &>/dev/null; then
    gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME} \
        --description="Service account para pipeline ETL de letras" \
        --display-name="Lyrics ETL Service Account"
    echo "✅ Service account criado: ${SERVICE_ACCOUNT_EMAIL}"
else
    echo "ℹ️ Service account já existe: ${SERVICE_ACCOUNT_EMAIL}"
fi

# Atribuir permissões
echo "🔑 Configurando permissões..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/bigquery.jobUser"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/storage.objectAdmin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/logging.logWriter"

echo "✅ Permissões configuradas"

# Build da imagem Docker
echo "🐳 Construindo imagem Docker..."
gcloud builds submit --tag ${IMAGE_NAME} .
echo "✅ Imagem construída: ${IMAGE_NAME}"

# Deploy do Cloud Run Job
echo "☁️ Fazendo deploy do Cloud Run Job..."
gcloud run jobs create ${SERVICE_NAME} \
    --image=${IMAGE_NAME} \
    --region=${REGION} \
    --service-account=${SERVICE_ACCOUNT_EMAIL} \
    --set-env-vars="GCP_PROJECT_ID=${PROJECT_ID},BQ_DATASET_ID=${DATASET_ID},GCS_BUCKET_NAME=${BUCKET_NAME}" \
    --memory=2Gi \
    --cpu=1 \
    --max-retries=3 \
    --parallelism=1 \
    --task-count=1 \
    --task-timeout=3600 \
    --args="--project-id=${PROJECT_ID},--dataset-id=${DATASET_ID},--bucket-name=${BUCKET_NAME}" \
    || gcloud run jobs update ${SERVICE_NAME} \
        --image=${IMAGE_NAME} \
        --region=${REGION} \
        --service-account=${SERVICE_ACCOUNT_EMAIL} \
        --set-env-vars="GCP_PROJECT_ID=${PROJECT_ID},BQ_DATASET_ID=${DATASET_ID},GCS_BUCKET_NAME=${BUCKET_NAME}" \
        --memory=2Gi \
        --cpu=1 \
        --max-retries=3 \
        --parallelism=1 \
        --task-count=1 \
        --task-timeout=3600 \
        --args="--project-id=${PROJECT_ID},--dataset-id=${DATASET_ID},--bucket-name=${BUCKET_NAME}"

echo "✅ Cloud Run Job deployado: ${SERVICE_NAME}"

# Criar Cloud Scheduler Job
echo "⏰ Criando agendamento..."
SCHEDULER_JOB_NAME="lyrics-etl-daily"

# Verificar se já existe
if gcloud scheduler jobs describe ${SCHEDULER_JOB_NAME} --location=${REGION} &>/dev/null; then
    echo "ℹ️ Job do scheduler já existe, atualizando..."
    gcloud scheduler jobs update http ${SCHEDULER_JOB_NAME} \
        --location=${REGION} \
        --schedule="0 2 * * *" \
        --time-zone="America/Sao_Paulo" \
        --uri="https://${REGION}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${PROJECT_ID}/jobs/${SERVICE_NAME}:run" \
        --http-method=POST \
        --oauth-service-account-email=${SERVICE_ACCOUNT_EMAIL}
else
    echo "📅 Criando novo job do scheduler..."
    gcloud scheduler jobs create http ${SCHEDULER_JOB_NAME} \
        --location=${REGION} \
        --schedule="0 2 * * *" \
        --time-zone="America/Sao_Paulo" \
        --uri="https://${REGION}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${PROJECT_ID}/jobs/${SERVICE_NAME}:run" \
        --http-method=POST \
        --oauth-service-account-email=${SERVICE_ACCOUNT_EMAIL} \
        --description="Execução diária do pipeline ETL de letras"
fi

echo "✅ Agendamento configurado: execução diária às 02:00"

# Teste de execução
echo "🧪 Testando execução do pipeline..."
echo "Para testar manualmente, execute:"
echo "gcloud run jobs execute ${SERVICE_NAME} --region=${REGION}"

# Criar dados de exemplo
echo "📝 Criando dados de exemplo..."
cat > /tmp/example_song.json << EOF
{
  "title": "Example Song",
  "artist": "Test Artist",
  "album": "Test Album",
  "genre": "Pop",
  "year": 2024,
  "lyrics": "This is an example song with happy lyrics about love and friendship. The melody is beautiful and the words are meaningful. It brings joy to everyone who listens."
}
EOF

gsutil cp /tmp/example_song.json gs://${BUCKET_NAME}/raw-data/
echo "✅ Dados de exemplo carregados"

# Informações finais
echo ""
echo "🎉 Deploy concluído com sucesso!"
echo ""
echo "📋 Resumo da infraestrutura:"
echo "  • Projeto: ${PROJECT_ID}"
echo "  • Região: ${REGION}"
echo "  • Bucket: gs://${BUCKET_NAME}"
echo "  • Dataset: ${PROJECT_ID}.${DATASET_ID}"
echo "  • Cloud Run Job: ${SERVICE_NAME}"
echo "  • Service Account: ${SERVICE_ACCOUNT_EMAIL}"
echo "  • Scheduler: ${SCHEDULER_JOB_NAME} (diário às 02:00)"
echo ""
echo "🔗 Links úteis:"
echo "  • Cloud Run Jobs: https://console.cloud.google.com/run/jobs?project=${PROJECT_ID}"
echo "  • BigQuery: https://console.cloud.google.com/bigquery?project=${PROJECT_ID}"
echo "  • Cloud Storage: https://console.cloud.google.com/storage/browser/${BUCKET_NAME}?project=${PROJECT_ID}"
echo "  • Cloud Scheduler: https://console.cloud.google.com/cloudscheduler?project=${PROJECT_ID}"
echo ""
echo "🚀 Para executar o pipeline manualmente:"
echo "  gcloud run jobs execute ${SERVICE_NAME} --region=${REGION}"
echo ""
echo "📊 Para visualizar os dados no BigQuery:"
echo "  SELECT * FROM \`${PROJECT_ID}.${DATASET_ID}.raw_lyrics\` LIMIT 10"

