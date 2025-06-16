# Pipeline GCP - Análise de Letras de Música

## Visão Geral

Este projeto implementa um pipeline completo de ETL (Extract, Transform, Load) no Google Cloud Platform para análise de letras de música usando técnicas de processamento de linguagem natural (NLP) e machine learning. O sistema processa automaticamente arquivos de texto contendo letras de música, extrai insights sobre sentimentos, complexidade textual e padrões linguísticos, e disponibiliza os resultados através de dashboards interativos.

### Características Principais

- **Pipeline ETL Automatizado**: Processamento batch de letras de música com Cloud Run Jobs
- **Análise NLP Avançada**: Análise de sentimentos, extração de características textuais e métricas de legibilidade
- **Armazenamento Escalável**: BigQuery como data warehouse com particionamento e clustering otimizados
- **Visualizações Interativas**: Dashboards em Data Studio/Looker com métricas em tempo real
- **Infraestrutura como Código**: Deploy automatizado com Terraform e scripts bash
- **Monitoramento Integrado**: Logs estruturados, métricas customizadas e alertas automáticos

### Arquitetura do Sistema

O pipeline segue uma arquitetura moderna de dados baseada em microserviços e serviços gerenciados do GCP:

1. **Camada de Ingestão**: Cloud Storage para armazenamento de dados brutos
2. **Camada de Processamento**: Cloud Run Jobs executando código Python com bibliotecas NLP
3. **Camada de Armazenamento**: BigQuery com esquema otimizado para análises
4. **Camada de Orquestração**: Cloud Scheduler para execução automatizada
5. **Camada de Visualização**: Data Studio/Looker para dashboards interativos
6. **Camada de Monitoramento**: Cloud Logging e Cloud Monitoring para observabilidade

## Pré-requisitos

### Ferramentas Necessárias

- **Google Cloud SDK (gcloud)**: Versão 400.0.0 ou superior
- **Terraform**: Versão 1.0 ou superior (opcional, para deploy com IaC)
- **Docker**: Versão 20.0 ou superior (para build local)
- **Python**: Versão 3.11 ou superior
- **Git**: Para versionamento de código

### Configuração do Ambiente GCP

1. **Projeto GCP**: Tenha um projeto GCP ativo com billing habilitado
2. **APIs Necessárias**: As seguintes APIs serão habilitadas automaticamente pelo script de deploy:
   - Cloud Build API
   - Cloud Run API
   - BigQuery API
   - Cloud Storage API
   - Cloud Logging API
   - Cloud Scheduler API
   - Artifact Registry API

3. **Permissões**: O usuário deve ter as seguintes roles no projeto:
   - `roles/owner` (recomendado) ou
   - `roles/editor` + `roles/iam.serviceAccountAdmin`

### Configuração Local

```bash
# 1. Instalar Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# 2. Autenticar no GCP
gcloud auth login
gcloud auth application-default login

# 3. Configurar projeto padrão
gcloud config set project SEU_PROJECT_ID

# 4. Verificar configuração
gcloud config list
```

## Instalação e Deploy

### Opção 1: Deploy Rápido com Script Bash

O método mais simples para deploy é usar o script automatizado:

```bash
# 1. Clonar o repositório
git clone <repository-url>
cd lyrics-etl-pipeline

# 2. Tornar script executável
chmod +x deploy.sh

# 3. Executar deploy
./deploy.sh SEU_PROJECT_ID us-central1

# 4. Aguardar conclusão (aproximadamente 10-15 minutos)
```

O script automaticamente:
- Habilita APIs necessárias
- Cria bucket Cloud Storage
- Configura dataset e tabelas BigQuery
- Cria service account com permissões adequadas
- Faz build e deploy da imagem Docker
- Configura Cloud Run Job
- Agenda execução diária com Cloud Scheduler
- Carrega dados de exemplo para teste

### Opção 2: Deploy com Terraform (Recomendado para Produção)

Para maior controle e reprodutibilidade:

```bash
# 1. Navegar para diretório Terraform
cd terraform

# 2. Copiar e configurar variáveis
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars com seus valores

# 3. Executar deploy
./deploy-terraform.sh deploy SEU_PROJECT_ID us-central1 prod

# 4. Verificar recursos criados
terraform output
```

### Verificação do Deploy

Após o deploy, verifique se todos os componentes foram criados:

```bash
# Verificar bucket
gsutil ls gs://SEU_PROJECT_ID-lyrics-data

# Verificar dataset BigQuery
bq ls SEU_PROJECT_ID:lyrics_analysis

# Verificar Cloud Run Job
gcloud run jobs list --region=us-central1

# Verificar agendamento
gcloud scheduler jobs list --location=us-central1
```

## Estrutura do Projeto

```
lyrics-etl-pipeline/
├── src/                          # Código fonte Python
│   ├── etl_processor.py         # Processador ETL principal
│   └── visualization_generator.py # Gerador de visualizações
├── config/                       # Configurações
│   └── config.py                # Configurações centralizadas
├── sql/                         # Scripts SQL
│   ├── create_tables.sql        # Criação de tabelas BigQuery
│   └── dashboard_queries.sql    # Queries para dashboards
├── terraform/                   # Infraestrutura como código
│   ├── main.tf                  # Configuração principal Terraform
│   ├── terraform.tfvars.example # Exemplo de variáveis
│   └── deploy-terraform.sh      # Script de deploy Terraform
├── tests/                       # Testes unitários
│   └── test_etl_processor.py    # Testes do processador ETL
├── dashboards/                  # Configurações de dashboards
│   └── dashboard_config.md      # Documentação dos dashboards
├── docker/                      # Arquivos Docker
├── requirements.txt             # Dependências Python
├── Dockerfile                   # Imagem Docker
├── deploy.sh                    # Script de deploy bash
├── VALIDATION_GUIDE.md          # Guia de validação e troubleshooting
└── README.md                    # Este arquivo
```

## Uso do Sistema

### Carregamento de Dados

O sistema suporta múltiplos formatos de entrada:

#### Formato JSON
```json
{
  "title": "Nome da Música",
  "artist": "Nome do Artista", 
  "album": "Nome do Álbum",
  "genre": "Gênero Musical",
  "year": 2024,
  "lyrics": "Letra completa da música..."
}
```

#### Formato CSV
```csv
title,artist,album,genre,year,lyrics
"Song Title","Artist Name","Album Name","Pop",2024,"Full lyrics here..."
```

#### Formato TXT
```
Título da Música
Letra da música linha por linha
Pode ter múltiplas linhas
...
```

### Upload de Dados

```bash
# Upload de arquivo único
gsutil cp minha_musica.json gs://SEU_PROJECT_ID-lyrics-data/raw-data/

# Upload de múltiplos arquivos
gsutil -m cp *.json gs://SEU_PROJECT_ID-lyrics-data/raw-data/

# Upload de diretório completo
gsutil -m cp -r ./letras_dataset/ gs://SEU_PROJECT_ID-lyrics-data/raw-data/
```

### Execução Manual do Pipeline

```bash
# Executar processamento imediato
gcloud run jobs execute lyrics-etl-pipeline --region=us-central1 --wait

# Verificar logs da execução
gcloud logs read "resource.type=cloud_run_job" --limit=50

# Verificar dados processados
bq query --use_legacy_sql=false "SELECT COUNT(*) FROM \`SEU_PROJECT_ID.lyrics_analysis.raw_lyrics\`"
```

### Acesso aos Dashboards

Após o processamento dos dados, acesse as visualizações:

1. **BigQuery Console**: https://console.cloud.google.com/bigquery
2. **Data Studio**: Conecte ao dataset `lyrics_analysis` 
3. **Visualizações Python**: Execute o gerador de visualizações:

```bash
python src/visualization_generator.py \
  --project-id SEU_PROJECT_ID \
  --dataset-id lyrics_analysis \
  --output-dir ./visualizations/
```

## Análises Disponíveis

### Métricas de Sentimento

- **Score de Sentimento**: Valor entre -1 (muito negativo) e +1 (muito positivo)
- **Classificação**: Positivo, Negativo ou Neutro
- **Confiança**: Nível de certeza da análise (0-1)
- **Palavras-chave**: Palavras que mais contribuem para o sentimento

### Métricas de Complexidade Textual

- **Contagem de Palavras**: Total de palavras na letra
- **Vocabulário Único**: Número de palavras distintas
- **Comprimento Médio**: Média de caracteres por palavra
- **Score de Legibilidade**: Facilidade de leitura (0-100, maior = mais fácil)

### Análises Comparativas

- **Por Gênero Musical**: Comparação de métricas entre gêneros
- **Por Década**: Evolução temporal das características
- **Por Artista**: Perfil individual e comparações
- **Por Popularidade**: Correlação com métricas de sucesso

### Análises de Palavras

- **Frequência Global**: Palavras mais comuns no dataset
- **TF-IDF**: Palavras mais características por música/artista
- **Co-ocorrência**: Palavras que aparecem juntas frequentemente
- **Tendências Temporais**: Evolução do uso de palavras específicas

## Monitoramento e Manutenção

### Logs e Métricas

O sistema gera logs estruturados para todas as operações:

```bash
# Visualizar logs do pipeline ETL
gcloud logs read "resource.type=cloud_run_job AND resource.labels.job_name=lyrics-etl-pipeline" --limit=100

# Logs de erro específicos
gcloud logs read "resource.type=cloud_run_job AND severity>=ERROR" --limit=50

# Métricas de performance
gcloud logging metrics list --filter="name:lyrics_etl"
```

### Alertas Configurados

- **Falhas de Execução**: Notificação quando o pipeline falha
- **Volume de Dados**: Alerta se não há novos dados por mais de 24h
- **Performance**: Alerta se execução demora mais que 1 hora
- **Qualidade**: Alerta se taxa de erro de processamento > 5%

### Manutenção Regular

#### Limpeza de Dados Antigos
```sql
-- Executar mensalmente para limpar dados > 1 ano
CALL `SEU_PROJECT_ID.lyrics_analysis.cleanup_old_data`(365);
```

#### Otimização de Tabelas
```sql
-- Reorganizar partições para melhor performance
ALTER TABLE `SEU_PROJECT_ID.lyrics_analysis.raw_lyrics` 
SET OPTIONS (partition_expiration_days = 365);
```

#### Backup de Configurações
```bash
# Backup das configurações Terraform
tar -czf backup-$(date +%Y%m%d).tar.gz terraform/

# Export de schemas BigQuery
bq extract --destination_format=AVRO \
  SEU_PROJECT_ID:lyrics_analysis.raw_lyrics \
  gs://SEU_PROJECT_ID-lyrics-data/backups/raw_lyrics_$(date +%Y%m%d).avro
```

## Troubleshooting

### Problemas Comuns

#### 1. Erro de Autenticação
```bash
# Solução
gcloud auth login
gcloud auth application-default login
```

#### 2. APIs Não Habilitadas
```bash
# Habilitar APIs manualmente
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable bigquery.googleapis.com
```

#### 3. Permissões Insuficientes
```bash
# Verificar permissões atuais
gcloud projects get-iam-policy SEU_PROJECT_ID

# Adicionar permissões necessárias
gcloud projects add-iam-policy-binding SEU_PROJECT_ID \
  --member="user:SEU_EMAIL" \
  --role="roles/editor"
```

#### 4. Falha no Build Docker
```bash
# Build local para debug
docker build -t lyrics-etl-local .
docker run --rm lyrics-etl-local python src/etl_processor.py --help
```

#### 5. Dados Não Processados
```bash
# Verificar arquivos no bucket
gsutil ls -la gs://SEU_PROJECT_ID-lyrics-data/raw-data/

# Verificar logs de processamento
gcloud logs read "resource.type=cloud_run_job" --limit=20

# Executar processamento manual
gcloud run jobs execute lyrics-etl-pipeline --region=us-central1
```

### Logs de Debug

Para debug detalhado, configure variáveis de ambiente:

```bash
# No Cloud Run Job
gcloud run jobs update lyrics-etl-pipeline \
  --region=us-central1 \
  --set-env-vars="LOG_LEVEL=DEBUG,PYTHONUNBUFFERED=1"
```

### Validação de Dados

Execute validações regulares:

```sql
-- Verificar integridade dos dados
SELECT 
  COUNT(*) as total_records,
  COUNT(DISTINCT id) as unique_ids,
  COUNT(*) - COUNT(DISTINCT id) as duplicates
FROM `SEU_PROJECT_ID.lyrics_analysis.raw_lyrics`;

-- Verificar completude das análises
SELECT 
  COUNT(r.id) as raw_count,
  COUNT(p.id) as processed_count,
  COUNT(s.lyrics_id) as sentiment_count
FROM `SEU_PROJECT_ID.lyrics_analysis.raw_lyrics` r
LEFT JOIN `SEU_PROJECT_ID.lyrics_analysis.processed_lyrics` p ON r.id = p.id
LEFT JOIN `SEU_PROJECT_ID.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id;
```

## Extensões e Customizações

### Adicionando Novos Tipos de Análise

1. **Modificar o Processador ETL**:
```python
# Em src/etl_processor.py, adicionar nova função
def _analyze_emotion(self, text: str) -> Dict:
    # Implementar análise de emoções
    pass
```

2. **Atualizar Schema BigQuery**:
```sql
-- Adicionar nova tabela
CREATE TABLE `SEU_PROJECT_ID.lyrics_analysis.emotion_analysis` (
  lyrics_id STRING,
  joy FLOAT64,
  sadness FLOAT64,
  anger FLOAT64,
  fear FLOAT64,
  analyzed_at TIMESTAMP
);
```

3. **Atualizar Dashboards**:
```sql
-- Nova view para dashboards
CREATE VIEW `SEU_PROJECT_ID.lyrics_analysis.emotion_summary` AS
SELECT 
  genre,
  AVG(joy) as avg_joy,
  AVG(sadness) as avg_sadness
FROM emotion_analysis e
JOIN raw_lyrics r ON e.lyrics_id = r.id
GROUP BY genre;
```

### Integrando Novas Fontes de Dados

1. **APIs de Música**: Spotify, Last.fm, MusicBrainz
2. **Scraping Web**: Genius, AZLyrics (respeitando robots.txt)
3. **Datasets Públicos**: Million Song Dataset, LyricFind

### Otimizações de Performance

1. **Paralelização**: Aumentar `parallelism` no Cloud Run Job
2. **Batch Processing**: Processar múltiplos arquivos por execução
3. **Caching**: Implementar cache Redis para resultados intermediários
4. **Streaming**: Migrar para Dataflow para processamento em tempo real

## Custos e Otimização

### Estimativa de Custos (por mês)

| Serviço | Uso Estimado | Custo Mensal (USD) |
|---------|--------------|-------------------|
| Cloud Storage | 10 GB | $0.20 |
| BigQuery | 100 GB armazenamento + 1 TB queries | $5.00 + $5.00 |
| Cloud Run Jobs | 100 execuções × 5 min | $2.00 |
| Cloud Scheduler | 30 jobs/mês | $0.10 |
| Cloud Logging | 10 GB logs | $0.50 |
| **Total** | | **~$12.80** |

### Otimizações de Custo

1. **Lifecycle Policies**: Mover dados antigos para Nearline/Coldline
2. **Particionamento**: Reduzir custo de queries BigQuery
3. **Clustering**: Otimizar performance de queries
4. **Scheduled Queries**: Pré-computar agregações caras
5. **Compression**: Usar formatos comprimidos (Parquet, Avro)

## Segurança e Compliance

### Medidas de Segurança Implementadas

1. **IAM Granular**: Service accounts com permissões mínimas necessárias
2. **Criptografia**: Dados criptografados em repouso e em trânsito
3. **VPC**: Isolamento de rede (opcional, para ambientes sensíveis)
4. **Audit Logs**: Rastreamento completo de todas as operações
5. **Secrets Management**: Uso do Secret Manager para credenciais

### Compliance

- **LGPD/GDPR**: Implementar anonimização de dados pessoais se necessário
- **Retenção**: Políticas de retenção configuráveis
- **Auditoria**: Logs completos para auditoria externa
- **Backup**: Estratégia de backup e recuperação

## Roadmap e Melhorias Futuras

### Versão 2.0 (Próximos 6 meses)

- [ ] **Análise de Emoções**: Detecção de emoções específicas (alegria, tristeza, raiva)
- [ ] **Análise de Temas**: Identificação automática de temas musicais
- [ ] **Comparação de Artistas**: Algoritmo de similaridade entre artistas
- [ ] **API REST**: Endpoint para consultas programáticas
- [ ] **Real-time Processing**: Migração para Dataflow/Pub/Sub

### Versão 3.0 (Longo prazo)

- [ ] **Machine Learning**: Modelos preditivos para sucesso de músicas
- [ ] **Análise de Áudio**: Integração com análise de características musicais
- [ ] **Recomendação**: Sistema de recomendação baseado em letras
- [ ] **Multi-idioma**: Suporte para análise em múltiplos idiomas
- [ ] **Mobile App**: Aplicativo móvel para visualização

## Contribuição

### Como Contribuir

1. **Fork** o repositório
2. **Crie** uma branch para sua feature (`git checkout -b feature/nova-analise`)
3. **Commit** suas mudanças (`git commit -am 'Adiciona nova análise de emoções'`)
4. **Push** para a branch (`git push origin feature/nova-analise`)
5. **Abra** um Pull Request

### Padrões de Código

- **Python**: Seguir PEP 8, usar type hints
- **SQL**: Usar convenções do BigQuery Standard SQL
- **Terraform**: Seguir convenções HashiCorp
- **Documentação**: Manter README e comentários atualizados

### Testes

```bash
# Executar todos os testes
python -m pytest tests/ -v

# Testes com cobertura
python -m pytest tests/ --cov=src --cov-report=html

# Testes de integração
python -m pytest tests/integration/ -v
```

## Suporte

### Canais de Suporte

- **Issues GitHub**: Para bugs e feature requests
- **Documentação**: Wiki do projeto com exemplos detalhados
- **Email**: suporte@projeto.com para questões específicas

### FAQ

**P: Como adicionar um novo gênero musical?**
R: Os gêneros são detectados automaticamente dos dados de entrada. Basta incluir o campo `genre` nos seus arquivos JSON/CSV.

**P: Posso processar letras em outros idiomas?**
R: Atualmente o sistema é otimizado para inglês. Para outros idiomas, seria necessário ajustar as bibliotecas NLP e stopwords.

**P: Como aumentar a frequência de processamento?**
R: Modifique o cron schedule no Cloud Scheduler ou execute manualmente quando necessário.

**P: Os dados são seguros?**
R: Sim, todos os dados são criptografados e o acesso é controlado via IAM do GCP.

## Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

## Agradecimentos

- **NLTK Team**: Pela excelente biblioteca de processamento de linguagem natural
- **Google Cloud**: Pela infraestrutura robusta e serviços gerenciados
- **Plotly**: Pelas visualizações interativas de alta qualidade
- **Comunidade Open Source**: Por todas as bibliotecas e ferramentas utilizadas

---

**Desenvolvido por**: Manus AI  
**Versão**: 1.0.0  
**Última Atualização**: Junho 2025

