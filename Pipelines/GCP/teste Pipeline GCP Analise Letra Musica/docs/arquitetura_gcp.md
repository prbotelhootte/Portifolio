# Arquitetura GCP - Pipeline de Análise de Letras de Música

## Visão Geral da Arquitetura

A arquitetura proposta para o pipeline de análise de letras de música no Google Cloud Platform (GCP) segue os princípios de uma arquitetura moderna de dados, utilizando serviços gerenciados para garantir escalabilidade, confiabilidade e facilidade de manutenção.

## Componentes da Arquitetura

### 1. Camada de Ingestão de Dados

#### Cloud Storage
- **Função**: Armazenamento de dados brutos (letras de música)
- **Formatos suportados**: TXT, JSON, CSV
- **Estrutura de buckets**:
  - `lyrics-raw-data/`: Dados brutos de entrada
  - `lyrics-processed/`: Dados processados temporários
  - `lyrics-models/`: Modelos de ML treinados
- **Configurações**:
  - Versionamento habilitado
  - Lifecycle policies para otimização de custos
  - Criptografia em repouso

### 2. Camada de Processamento

#### Cloud Run Jobs
- **Função**: Execução do pipeline ETL
- **Características**:
  - Containerizado com Docker
  - Escalabilidade automática
  - Execução sob demanda
  - Suporte a Python 3.11+
- **Bibliotecas incluídas**:
  - NLTK para processamento de linguagem natural
  - scikit-learn para machine learning
  - pandas/numpy para manipulação de dados
  - google-cloud-bigquery para integração

### 3. Camada de Orquestração

#### Cloud Scheduler
- **Função**: Agendamento automático dos jobs ETL
- **Configurações**:
  - Execução diária, semanal ou sob demanda
  - Retry policies configuráveis
  - Notificações de falha

### 4. Camada de Armazenamento Analítico

#### BigQuery
- **Função**: Data warehouse para análises
- **Estrutura de tabelas**:

##### Tabela: `raw_lyrics`
```sql
CREATE TABLE `projeto.dataset.raw_lyrics` (
  id STRING,
  title STRING,
  artist STRING,
  album STRING,
  genre STRING,
  year INT64,
  lyrics TEXT,
  source STRING,
  created_at TIMESTAMP,
  file_path STRING
);
```

##### Tabela: `processed_lyrics`
```sql
CREATE TABLE `projeto.dataset.processed_lyrics` (
  id STRING,
  title STRING,
  artist STRING,
  word_count INT64,
  unique_words INT64,
  avg_word_length FLOAT64,
  readability_score FLOAT64,
  language STRING,
  processed_text TEXT,
  tokens ARRAY<STRING>,
  processed_at TIMESTAMP
);
```

##### Tabela: `word_frequency`
```sql
CREATE TABLE `projeto.dataset.word_frequency` (
  lyrics_id STRING,
  word STRING,
  frequency INT64,
  tf_idf FLOAT64,
  pos_tag STRING,
  is_stopword BOOLEAN,
  created_at TIMESTAMP
);
```

##### Tabela: `sentiment_analysis`
```sql
CREATE TABLE `projeto.dataset.sentiment_analysis` (
  lyrics_id STRING,
  sentiment_score FLOAT64,
  sentiment_label STRING,
  confidence FLOAT64,
  positive_words ARRAY<STRING>,
  negative_words ARRAY<STRING>,
  neutral_words ARRAY<STRING>,
  analyzed_at TIMESTAMP
);
```

### 5. Camada de Visualização

#### Data Studio / Looker
- **Dashboards principais**:
  - Análise de sentimentos por gênero musical
  - Evolução temporal das letras
  - Palavras mais frequentes
  - Comparação entre artistas
  - Métricas de complexidade textual

### 6. Camada de Monitoramento

#### Cloud Logging
- **Logs capturados**:
  - Execução dos jobs ETL
  - Erros de processamento
  - Métricas de performance
  - Auditoria de acesso aos dados

#### Cloud Monitoring
- **Métricas monitoradas**:
  - Tempo de execução dos jobs
  - Taxa de sucesso/falha
  - Utilização de recursos
  - Latência das consultas BigQuery

### 7. Camada de Segurança

#### IAM (Identity and Access Management)
- **Service Accounts**:
  - `etl-processor@projeto.iam.gserviceaccount.com`
  - `dashboard-viewer@projeto.iam.gserviceaccount.com`
  - `data-analyst@projeto.iam.gserviceaccount.com`

- **Roles e Permissões**:
  - Cloud Run Invoker
  - BigQuery Data Editor
  - Storage Object Admin
  - Logging Writer

## Fluxo de Dados

### 1. Ingestão
1. Arquivos de letras são carregados no bucket `lyrics-raw-data/`
2. Cloud Storage trigger notifica sobre novos arquivos
3. Cloud Scheduler inicia o job ETL conforme cronograma

### 2. Processamento
1. Cloud Run Job lê arquivos do Cloud Storage
2. Aplica transformações NLP:
   - Tokenização
   - Remoção de stopwords
   - Análise de sentimentos
   - Extração de características
3. Valida e limpa os dados
4. Carrega dados processados no BigQuery

### 3. Análise e Visualização
1. Data Studio conecta ao BigQuery
2. Dashboards são atualizados automaticamente
3. Usuários acessam visualizações em tempo real

## Vantagens da Arquitetura

### Escalabilidade
- Cloud Run escala automaticamente baseado na demanda
- BigQuery suporta petabytes de dados
- Cloud Storage oferece armazenamento ilimitado

### Confiabilidade
- Serviços gerenciados com SLA de 99.9%
- Backup automático e recuperação de desastres
- Retry automático em caso de falhas

### Custo-Efetividade
- Modelo pay-per-use
- Otimização automática de recursos
- Lifecycle policies para redução de custos

### Segurança
- Criptografia end-to-end
- Controle granular de acesso
- Auditoria completa de atividades

## Considerações de Implementação

### Performance
- Particionamento de tabelas BigQuery por data
- Clustering por artista/gênero para otimizar consultas
- Cache de resultados frequentes

### Manutenibilidade
- Código versionado no Cloud Source Repositories
- CI/CD com Cloud Build
- Testes automatizados

### Monitoramento
- Alertas automáticos para falhas
- Dashboards de operação
- Métricas de qualidade de dados

