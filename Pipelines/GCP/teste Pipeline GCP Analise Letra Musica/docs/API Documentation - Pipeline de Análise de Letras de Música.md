# API Documentation - Pipeline de Análise de Letras de Música

## Visão Geral

Esta documentação descreve as interfaces programáticas disponíveis no pipeline de análise de letras de música, incluindo schemas de dados, endpoints de consulta BigQuery e exemplos de uso.

## Schemas de Dados

### Tabela: raw_lyrics

Armazena dados brutos das letras de música.

| Campo | Tipo | Modo | Descrição |
|-------|------|------|-----------|
| `id` | STRING | REQUIRED | Identificador único da música (hash MD5) |
| `title` | STRING | NULLABLE | Título da música |
| `artist` | STRING | NULLABLE | Nome do artista |
| `album` | STRING | NULLABLE | Nome do álbum |
| `genre` | STRING | NULLABLE | Gênero musical |
| `year` | INTEGER | NULLABLE | Ano de lançamento |
| `lyrics` | STRING | NULLABLE | Letra completa da música |
| `source` | STRING | NULLABLE | Arquivo fonte dos dados |
| `created_at` | TIMESTAMP | NULLABLE | Timestamp de criação |
| `file_path` | STRING | NULLABLE | Caminho do arquivo original |

**Exemplo de Registro:**
```json
{
  "id": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6",
  "title": "Imagine",
  "artist": "John Lennon",
  "album": "Imagine",
  "genre": "Rock",
  "year": 1971,
  "lyrics": "Imagine there's no heaven...",
  "source": "classic_rock_songs.json",
  "created_at": "2024-06-13T10:30:00Z",
  "file_path": "gs://bucket/raw-data/classic_rock_songs.json"
}
```

### Tabela: processed_lyrics

Contém métricas de processamento NLP das letras.

| Campo | Tipo | Modo | Descrição |
|-------|------|------|-----------|
| `id` | STRING | REQUIRED | Identificador da música (FK para raw_lyrics) |
| `title` | STRING | NULLABLE | Título da música |
| `artist` | STRING | NULLABLE | Nome do artista |
| `word_count` | INTEGER | NULLABLE | Total de palavras na letra |
| `unique_words` | INTEGER | NULLABLE | Número de palavras únicas |
| `avg_word_length` | FLOAT | NULLABLE | Comprimento médio das palavras |
| `readability_score` | FLOAT | NULLABLE | Score de legibilidade (0-100) |
| `language` | STRING | NULLABLE | Idioma detectado |
| `processed_text` | STRING | NULLABLE | Texto limpo e processado |
| `tokens` | STRING | NULLABLE | Array de tokens como JSON string |
| `processed_at` | TIMESTAMP | NULLABLE | Timestamp do processamento |

**Exemplo de Registro:**
```json
{
  "id": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6",
  "title": "Imagine",
  "artist": "John Lennon",
  "word_count": 156,
  "unique_words": 89,
  "avg_word_length": 4.2,
  "readability_score": 78.5,
  "language": "en",
  "processed_text": "imagine heaven easy try imagine countries...",
  "tokens": "[\"imagine\", \"heaven\", \"easy\", \"try\"]",
  "processed_at": "2024-06-13T10:35:00Z"
}
```

### Tabela: word_frequency

Análise de frequência de palavras por música.

| Campo | Tipo | Modo | Descrição |
|-------|------|------|-----------|
| `lyrics_id` | STRING | REQUIRED | ID da música (FK) |
| `word` | STRING | REQUIRED | Palavra analisada |
| `frequency` | INTEGER | NULLABLE | Frequência da palavra na música |
| `tf_idf` | FLOAT | NULLABLE | Score TF-IDF da palavra |
| `pos_tag` | STRING | NULLABLE | Part-of-speech tag |
| `is_stopword` | BOOLEAN | NULLABLE | Se é uma stopword |
| `created_at` | TIMESTAMP | NULLABLE | Timestamp da análise |

**Exemplo de Registro:**
```json
{
  "lyrics_id": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6",
  "word": "imagine",
  "frequency": 8,
  "tf_idf": 0.342,
  "pos_tag": "VB",
  "is_stopword": false,
  "created_at": "2024-06-13T10:35:00Z"
}
```

### Tabela: sentiment_analysis

Resultados da análise de sentimentos.

| Campo | Tipo | Modo | Descrição |
|-------|------|------|-----------|
| `lyrics_id` | STRING | REQUIRED | ID da música (FK) |
| `sentiment_score` | FLOAT | NULLABLE | Score de sentimento (-1 a +1) |
| `sentiment_label` | STRING | NULLABLE | Classificação (positive/negative/neutral) |
| `confidence` | FLOAT | NULLABLE | Confiança da análise (0-1) |
| `positive_words` | STRING | NULLABLE | Palavras positivas como JSON array |
| `negative_words` | STRING | NULLABLE | Palavras negativas como JSON array |
| `neutral_words` | STRING | NULLABLE | Palavras neutras como JSON array |
| `analyzed_at` | TIMESTAMP | NULLABLE | Timestamp da análise |

**Exemplo de Registro:**
```json
{
  "lyrics_id": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6",
  "sentiment_score": 0.65,
  "sentiment_label": "positive",
  "confidence": 0.87,
  "positive_words": "[\"peace\", \"love\", \"hope\", \"dream\"]",
  "negative_words": "[\"war\", \"hate\"]",
  "neutral_words": "[\"people\", \"world\", \"country\"]",
  "analyzed_at": "2024-06-13T10:35:00Z"
}
```

## Views Pré-definidas

### dataset_overview

Visão geral do dataset com métricas principais.

```sql
SELECT * FROM `project.lyrics_analysis.dataset_overview`;
```

**Campos Retornados:**
- `total_songs`: Total de músicas no dataset
- `total_artists`: Número de artistas únicos
- `total_genres`: Número de gêneros únicos
- `years_span`: Quantidade de anos cobertos
- `earliest_year`: Ano mais antigo
- `latest_year`: Ano mais recente
- `avg_words_per_song`: Média de palavras por música
- `avg_readability`: Score médio de legibilidade
- `avg_sentiment`: Sentimento médio global

### sentiment_by_genre

Análise de sentimentos agrupada por gênero musical.

```sql
SELECT * FROM `project.lyrics_analysis.sentiment_by_genre`
ORDER BY avg_sentiment_score DESC;
```

**Campos Retornados:**
- `genre`: Gênero musical
- `song_count`: Número de músicas
- `avg_sentiment_score`: Score médio de sentimento
- `sentiment_stddev`: Desvio padrão do sentimento
- `positive_percentage`: Percentual de músicas positivas
- `negative_percentage`: Percentual de músicas negativas
- `neutral_percentage`: Percentual de músicas neutras
- `avg_confidence`: Confiança média das análises

### top_artists_by_volume

Ranking de artistas por volume de músicas.

```sql
SELECT * FROM `project.lyrics_analysis.top_artists_by_volume`
LIMIT 20;
```

**Campos Retornados:**
- `artist`: Nome do artista
- `song_count`: Número de músicas
- `avg_word_count`: Média de palavras por música
- `avg_readability`: Legibilidade média
- `avg_sentiment`: Sentimento médio
- `dominant_sentiment`: Sentimento predominante
- `genres`: Gêneros do artista

## Queries de Exemplo

### 1. Buscar Músicas por Artista

```sql
SELECT 
  r.title,
  r.year,
  r.genre,
  p.word_count,
  s.sentiment_score,
  s.sentiment_label
FROM `project.lyrics_analysis.raw_lyrics` r
JOIN `project.lyrics_analysis.processed_lyrics` p ON r.id = p.id
JOIN `project.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
WHERE LOWER(r.artist) = LOWER('John Lennon')
ORDER BY r.year DESC;
```

### 2. Top Palavras Mais Frequentes

```sql
SELECT 
  word,
  SUM(frequency) as total_frequency,
  COUNT(DISTINCT lyrics_id) as songs_with_word,
  AVG(tf_idf) as avg_tfidf
FROM `project.lyrics_analysis.word_frequency`
WHERE is_stopword = FALSE 
  AND LENGTH(word) >= 3
GROUP BY word
ORDER BY total_frequency DESC
LIMIT 50;
```

### 3. Evolução do Sentimento por Década

```sql
SELECT 
  FLOOR(r.year / 10) * 10 as decade,
  COUNT(*) as song_count,
  AVG(s.sentiment_score) as avg_sentiment,
  STDDEV(s.sentiment_score) as sentiment_variation
FROM `project.lyrics_analysis.raw_lyrics` r
JOIN `project.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
WHERE r.year IS NOT NULL 
  AND r.year BETWEEN 1950 AND 2024
GROUP BY decade
ORDER BY decade;
```

### 4. Análise de Complexidade por Gênero

```sql
SELECT 
  r.genre,
  COUNT(*) as song_count,
  AVG(p.word_count) as avg_words,
  AVG(p.unique_words) as avg_unique_words,
  AVG(p.readability_score) as avg_readability,
  AVG(p.unique_words / p.word_count) as vocabulary_diversity
FROM `project.lyrics_analysis.raw_lyrics` r
JOIN `project.lyrics_analysis.processed_lyrics` p ON r.id = p.id
WHERE r.genre != 'Unknown' 
  AND p.word_count > 0
GROUP BY r.genre
HAVING song_count >= 10
ORDER BY avg_readability DESC;
```

### 5. Buscar Músicas Similares por Sentimento

```sql
WITH target_song AS (
  SELECT sentiment_score, sentiment_label
  FROM `project.lyrics_analysis.sentiment_analysis`
  WHERE lyrics_id = 'TARGET_SONG_ID'
)
SELECT 
  r.title,
  r.artist,
  s.sentiment_score,
  ABS(s.sentiment_score - target_song.sentiment_score) as sentiment_diff
FROM `project.lyrics_analysis.raw_lyrics` r
JOIN `project.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
CROSS JOIN target_song
WHERE s.sentiment_label = target_song.sentiment_label
  AND r.id != 'TARGET_SONG_ID'
ORDER BY sentiment_diff ASC
LIMIT 10;
```

## Funções Personalizadas

### get_word_trend(word)

Retorna a evolução temporal de uma palavra específica.

```sql
SELECT * FROM `project.lyrics_analysis.get_word_trend`('love')
ORDER BY year;
```

**Parâmetros:**
- `word` (STRING): Palavra a ser analisada

**Retorna:**
- `year`: Ano
- `frequency`: Frequência total da palavra
- `song_count`: Número de músicas com a palavra
- `avg_tfidf`: Score TF-IDF médio

### analyze_artist(artist_name)

Análise completa de um artista específico.

```sql
CALL `project.lyrics_analysis.analyze_artist`('John Lennon');
```

**Parâmetros:**
- `artist_name` (STRING): Nome do artista

**Retorna:**
- Métricas gerais do artista
- Top 20 palavras mais características

## Procedures

### cleanup_old_data(days_to_keep)

Remove dados antigos das tabelas particionadas.

```sql
CALL `project.lyrics_analysis.cleanup_old_data`(365);
```

**Parâmetros:**
- `days_to_keep` (INT64): Número de dias para manter

## Endpoints REST (Futuro)

### GET /api/v1/songs

Lista músicas com filtros opcionais.

**Parâmetros de Query:**
- `artist`: Filtrar por artista
- `genre`: Filtrar por gênero
- `year_min`: Ano mínimo
- `year_max`: Ano máximo
- `sentiment`: Filtrar por sentimento (positive/negative/neutral)
- `limit`: Número máximo de resultados (padrão: 100)
- `offset`: Offset para paginação (padrão: 0)

**Exemplo:**
```
GET /api/v1/songs?artist=John%20Lennon&genre=Rock&limit=10
```

**Resposta:**
```json
{
  "total": 156,
  "limit": 10,
  "offset": 0,
  "songs": [
    {
      "id": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6",
      "title": "Imagine",
      "artist": "John Lennon",
      "genre": "Rock",
      "year": 1971,
      "sentiment_score": 0.65,
      "sentiment_label": "positive",
      "word_count": 156,
      "readability_score": 78.5
    }
  ]
}
```

### GET /api/v1/songs/{id}

Detalhes de uma música específica.

**Parâmetros:**
- `id`: ID da música

**Resposta:**
```json
{
  "id": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6",
  "title": "Imagine",
  "artist": "John Lennon",
  "album": "Imagine",
  "genre": "Rock",
  "year": 1971,
  "lyrics": "Imagine there's no heaven...",
  "metrics": {
    "word_count": 156,
    "unique_words": 89,
    "avg_word_length": 4.2,
    "readability_score": 78.5,
    "sentiment_score": 0.65,
    "sentiment_label": "positive",
    "confidence": 0.87
  },
  "top_words": [
    {"word": "imagine", "frequency": 8, "tf_idf": 0.342},
    {"word": "people", "frequency": 6, "tf_idf": 0.289}
  ]
}
```

### GET /api/v1/artists/{name}/stats

Estatísticas de um artista.

**Parâmetros:**
- `name`: Nome do artista

**Resposta:**
```json
{
  "artist": "John Lennon",
  "total_songs": 23,
  "avg_sentiment": 0.45,
  "dominant_sentiment": "positive",
  "avg_readability": 72.3,
  "avg_word_count": 167,
  "genres": ["Rock", "Pop"],
  "active_years": {
    "start": 1970,
    "end": 1980
  },
  "characteristic_words": [
    {"word": "imagine", "tf_idf": 0.456},
    {"word": "peace", "tf_idf": 0.398}
  ]
}
```

### POST /api/v1/analyze

Análise de texto em tempo real.

**Body:**
```json
{
  "text": "Imagine all the people living life in peace",
  "include_sentiment": true,
  "include_readability": true,
  "include_word_frequency": true
}
```

**Resposta:**
```json
{
  "text": "Imagine all the people living life in peace",
  "metrics": {
    "word_count": 9,
    "unique_words": 8,
    "avg_word_length": 4.7,
    "readability_score": 85.2,
    "sentiment_score": 0.72,
    "sentiment_label": "positive",
    "confidence": 0.91
  },
  "word_frequency": [
    {"word": "imagine", "frequency": 1, "pos_tag": "VB"},
    {"word": "people", "frequency": 1, "pos_tag": "NNS"}
  ],
  "processing_time_ms": 245
}
```

## Códigos de Erro

### BigQuery Errors

| Código | Descrição | Solução |
|--------|-----------|---------|
| `400` | Invalid query syntax | Verificar sintaxe SQL |
| `403` | Permission denied | Verificar permissões IAM |
| `404` | Table not found | Verificar nome da tabela/dataset |
| `500` | Internal server error | Tentar novamente ou contatar suporte |

### API Errors (Futuro)

| Código | Descrição | Exemplo |
|--------|-----------|---------|
| `400` | Bad Request | Parâmetros inválidos |
| `401` | Unauthorized | Token de autenticação inválido |
| `404` | Not Found | Recurso não encontrado |
| `429` | Rate Limit Exceeded | Muitas requisições |
| `500` | Internal Server Error | Erro interno do servidor |

## Limites e Quotas

### BigQuery

- **Query timeout**: 6 horas
- **Resultado máximo**: 10 GB
- **Queries simultâneas**: 100 por projeto
- **Slots**: Baseado no tipo de projeto

### Cloud Storage

- **Tamanho máximo de arquivo**: 5 TB
- **Operações por segundo**: 5000 por bucket
- **Bandwidth**: Sem limite específico

### Cloud Run Jobs

- **Timeout máximo**: 24 horas
- **Memória máxima**: 32 GB
- **CPU máximo**: 8 vCPUs
- **Execuções simultâneas**: 1000 por região

## Versionamento

A API segue versionamento semântico (SemVer):

- **v1.0.0**: Versão inicial com funcionalidades básicas
- **v1.1.0**: Adição de endpoints REST
- **v1.2.0**: Melhorias de performance e novas métricas
- **v2.0.0**: Breaking changes na estrutura de dados

## Autenticação e Autorização

### BigQuery

```python
from google.cloud import bigquery

# Usando credenciais padrão
client = bigquery.Client(project='your-project-id')

# Usando service account key
client = bigquery.Client.from_service_account_json('path/to/key.json')
```

### API REST (Futuro)

```bash
# Obter token de acesso
gcloud auth print-access-token

# Usar em requisições
curl -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     https://api.lyrics-analysis.com/v1/songs
```

## Rate Limiting

### BigQuery

- **Queries por dia**: 100,000 (pode ser aumentado)
- **Queries por usuário por 100 segundos**: 100
- **Queries simultâneas**: 50 por usuário

### API REST (Futuro)

- **Requests por minuto**: 1000 por usuário
- **Requests por dia**: 100,000 por usuário
- **Burst limit**: 100 requests em 10 segundos

## Exemplos de Integração

### Python

```python
from google.cloud import bigquery
import pandas as pd

def get_artist_songs(project_id, artist_name):
    client = bigquery.Client(project=project_id)
    
    query = f"""
    SELECT 
      r.title,
      r.year,
      s.sentiment_score,
      p.readability_score
    FROM `{project_id}.lyrics_analysis.raw_lyrics` r
    JOIN `{project_id}.lyrics_analysis.processed_lyrics` p ON r.id = p.id
    JOIN `{project_id}.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
    WHERE LOWER(r.artist) = LOWER(@artist_name)
    ORDER BY r.year DESC
    """
    
    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("artist_name", "STRING", artist_name)
        ]
    )
    
    df = client.query(query, job_config=job_config).to_dataframe()
    return df

# Uso
songs = get_artist_songs('your-project-id', 'John Lennon')
print(songs.head())
```

### JavaScript/Node.js

```javascript
const {BigQuery} = require('@google-cloud/bigquery');

async function getGenreStats(projectId, genre) {
  const bigquery = new BigQuery({projectId});
  
  const query = `
    SELECT 
      COUNT(*) as song_count,
      AVG(sentiment_score) as avg_sentiment,
      AVG(readability_score) as avg_readability
    FROM \`${projectId}.lyrics_analysis.raw_lyrics\` r
    JOIN \`${projectId}.lyrics_analysis.processed_lyrics\` p ON r.id = p.id
    JOIN \`${projectId}.lyrics_analysis.sentiment_analysis\` s ON r.id = s.lyrics_id
    WHERE LOWER(r.genre) = LOWER(@genre)
  `;
  
  const options = {
    query: query,
    params: {genre: genre}
  };
  
  const [rows] = await bigquery.query(options);
  return rows[0];
}

// Uso
getGenreStats('your-project-id', 'Rock')
  .then(stats => console.log(stats))
  .catch(console.error);
```

### R

```r
library(bigrquery)
library(dplyr)

# Configurar projeto
project_id <- "your-project-id"
bq_auth()

# Função para buscar dados
get_sentiment_trends <- function(project_id) {
  query <- paste0("
    SELECT 
      EXTRACT(YEAR FROM created_at) as year,
      AVG(sentiment_score) as avg_sentiment,
      COUNT(*) as song_count
    FROM `", project_id, ".lyrics_analysis.sentiment_analysis`
    WHERE EXTRACT(YEAR FROM analyzed_at) >= 2000
    GROUP BY year
    ORDER BY year
  ")
  
  bq_table_download(bq_project_query(project_id, query))
}

# Uso
trends <- get_sentiment_trends(project_id)
plot(trends$year, trends$avg_sentiment, type="l")
```

---

**Versão da API**: 1.0.0  
**Última Atualização**: Junho 2025  
**Suporte**: api-support@lyrics-analysis.com

