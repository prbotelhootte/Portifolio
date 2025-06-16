# Configuração de Dashboards - Data Studio/Looker
# Pipeline de Análise de Letras de Música

## Métricas e KPIs Principais

### 1. Métricas de Visão Geral
- **Total de Músicas**: Contagem total de letras processadas
- **Total de Artistas**: Número único de artistas no dataset
- **Total de Gêneros**: Diversidade de gêneros musicais
- **Período Temporal**: Span de anos coberto pelo dataset
- **Sentimento Médio Global**: Score médio de sentimento (-1 a +1)
- **Legibilidade Média**: Score médio de legibilidade (0-100)

### 2. Métricas de Qualidade dos Dados
- **Taxa de Completude**: Percentual de campos preenchidos
- **Músicas com Análise Completa**: Letras com todas as análises processadas
- **Distribuição por Fonte**: Origem dos dados (arquivos, APIs, etc.)
- **Última Atualização**: Timestamp do último processamento

### 3. Métricas de Sentimento
- **Distribuição de Sentimentos**: Percentual positivo/negativo/neutro
- **Confiança Média**: Score médio de confiança das análises
- **Sentimento por Gênero**: Comparação entre gêneros musicais
- **Evolução Temporal**: Tendência de sentimentos ao longo dos anos

### 4. Métricas de Complexidade Textual
- **Palavras por Música**: Média de palavras por letra
- **Vocabulário Único**: Diversidade vocabular média
- **Comprimento Médio de Palavras**: Complexidade lexical
- **Score de Legibilidade**: Facilidade de leitura

## Estrutura de Dashboards

### Dashboard 1: Visão Geral Executiva

#### Seção Superior - KPIs Principais
```
[Total Músicas]  [Total Artistas]  [Sentimento Médio]  [Legibilidade Média]
    15,432           2,847             +0.12              67.3
```

#### Seção Central - Gráficos Principais
- **Gráfico de Linha**: Evolução do sentimento ao longo dos anos
- **Gráfico de Barras**: Top 10 gêneros por volume de músicas
- **Gráfico de Pizza**: Distribuição de sentimentos (Positivo/Negativo/Neutro)
- **Heatmap**: Sentimento por gênero e década

#### Seção Inferior - Tabelas
- **Top Artistas**: Por volume de músicas e sentimento médio
- **Palavras Mais Frequentes**: Globalmente e por sentimento

### Dashboard 2: Análise de Sentimentos

#### Filtros Interativos
- Período temporal (slider de anos)
- Gêneros musicais (multi-select)
- Artistas (search box)
- Nível de confiança mínimo

#### Visualizações Principais
- **Gráfico de Área**: Evolução temporal dos sentimentos
- **Box Plot**: Distribuição de sentimentos por gênero
- **Scatter Plot**: Correlação entre legibilidade e sentimento
- **Treemap**: Artistas por volume e sentimento dominante

#### Métricas Detalhadas
- Sentimento médio por período
- Variação de sentimento (desvio padrão)
- Top palavras positivas/negativas
- Artistas mais/menos positivos

### Dashboard 3: Análise de Complexidade Textual

#### Métricas de Complexidade
- **Histograma**: Distribuição de contagem de palavras
- **Gráfico de Barras**: Legibilidade média por gênero
- **Gráfico de Linha**: Evolução da complexidade ao longo do tempo
- **Radar Chart**: Perfil de complexidade por artista

#### Análises Comparativas
- Complexidade por década
- Diversidade vocabular por gênero
- Correlação entre popularidade e complexidade
- Tendências de simplificação/complexificação

### Dashboard 4: Análise de Palavras e Temas

#### Word Clouds Interativas
- Palavras mais frequentes globalmente
- Palavras por sentimento (positivo/negativo)
- Palavras por gênero musical
- Palavras por década

#### Análises de Frequência
- **Gráfico de Barras**: Top 50 palavras mais frequentes
- **Gráfico de Linha**: Tendência de palavras específicas ao longo do tempo
- **Heatmap**: Frequência de palavras por gênero
- **Network Graph**: Relações entre palavras (co-ocorrência)

### Dashboard 5: Análise de Artistas

#### Perfil Individual de Artistas
- Métricas gerais (total de músicas, período ativo)
- Evolução do sentimento ao longo da carreira
- Palavras características (TF-IDF alto)
- Comparação com média do gênero

#### Rankings e Comparações
- **Tabela Rankeada**: Artistas por diferentes métricas
- **Gráfico de Dispersão**: Posicionamento de artistas (sentimento vs complexidade)
- **Gráfico de Barras**: Produtividade por década
- **Sankey Diagram**: Fluxo de artistas entre gêneros

## Configurações Técnicas

### Conexões de Dados

#### BigQuery como Fonte Principal
```json
{
  "connection_type": "BigQuery",
  "project_id": "${PROJECT_ID}",
  "dataset_id": "lyrics_analysis",
  "tables": [
    "raw_lyrics",
    "processed_lyrics", 
    "word_frequency",
    "sentiment_analysis"
  ],
  "views": [
    "dataset_overview",
    "sentiment_by_genre",
    "sentiment_evolution",
    "global_word_frequency"
  ]
}
```

#### Configurações de Cache
- **Refresh automático**: A cada 6 horas
- **Cache de queries**: 1 hora para consultas complexas
- **Incremental refresh**: Apenas dados novos desde última atualização

### Filtros Globais

#### Filtros Temporais
- **Período**: Slider de anos (1950-2024)
- **Década**: Dropdown com décadas
- **Ano específico**: Input numérico

#### Filtros Categóricos
- **Gênero**: Multi-select com todos os gêneros
- **Artista**: Search box com autocomplete
- **Sentimento**: Dropdown (Positivo/Negativo/Neutro/Todos)

#### Filtros Numéricos
- **Mínimo de músicas**: Para filtrar artistas/gêneros com volume mínimo
- **Confiança mínima**: Para análises de sentimento
- **Faixa de legibilidade**: Slider para scores de legibilidade

### Configurações de Visualização

#### Paleta de Cores
```css
/* Sentimentos */
--positive-color: #4CAF50;
--negative-color: #F44336;
--neutral-color: #9E9E9E;

/* Gêneros (exemplo) */
--rock-color: #E91E63;
--pop-color: #2196F3;
--hip-hop-color: #FF9800;
--country-color: #795548;
--electronic-color: #9C27B0;

/* Gradientes */
--sentiment-gradient: linear-gradient(90deg, #F44336 0%, #9E9E9E 50%, #4CAF50 100%);
--time-gradient: linear-gradient(90deg, #1976D2 0%, #42A5F5 100%);
```

#### Formatação de Números
- **Sentimento**: 2 casas decimais, range -1.00 a +1.00
- **Percentuais**: 1 casa decimal com símbolo %
- **Contagens**: Formatação com separadores de milhares
- **Scores**: 1 casa decimal para legibilidade

### Interatividade

#### Drill-down Hierárquico
1. **Gênero** → **Artista** → **Música específica**
2. **Década** → **Ano** → **Mês** (se disponível)
3. **Sentimento geral** → **Palavras específicas** → **Contexto**

#### Cross-filtering
- Seleção em um gráfico filtra todos os outros
- Filtros persistem entre dashboards
- Breadcrumbs para navegação

#### Tooltips Informativos
- Contexto adicional em hover
- Métricas secundárias
- Links para análises detalhadas

## Alertas e Monitoramento

### Alertas de Qualidade de Dados
- **Queda no volume**: Redução significativa de novos dados
- **Anomalias de sentimento**: Mudanças bruscas inexplicáveis
- **Falhas de processamento**: Erros no pipeline ETL

### Métricas de Performance
- **Tempo de carregamento**: Dashboards devem carregar em <3s
- **Atualização de dados**: Máximo 6h de defasagem
- **Disponibilidade**: 99.9% uptime

### Notificações
- **Email**: Para administradores em caso de falhas
- **Slack/Teams**: Notificações em tempo real
- **Dashboard de status**: Página dedicada ao health do sistema

## Exemplos de Queries para Data Studio

### Query 1: Métricas Principais
```sql
SELECT 
  COUNT(DISTINCT r.id) as total_songs,
  COUNT(DISTINCT r.artist) as total_artists,
  AVG(s.sentiment_score) as avg_sentiment,
  AVG(p.readability_score) as avg_readability
FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r
LEFT JOIN `${PROJECT_ID}.lyrics_analysis.processed_lyrics` p ON r.id = p.id
LEFT JOIN `${PROJECT_ID}.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
WHERE r.lyrics IS NOT NULL
```

### Query 2: Evolução Temporal
```sql
SELECT 
  r.year,
  COUNT(*) as song_count,
  AVG(s.sentiment_score) as avg_sentiment,
  AVG(p.readability_score) as avg_readability
FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r
JOIN `${PROJECT_ID}.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
JOIN `${PROJECT_ID}.lyrics_analysis.processed_lyrics` p ON r.id = p.id
WHERE r.year BETWEEN @start_year AND @end_year
GROUP BY r.year
ORDER BY r.year
```

### Query 3: Top Palavras
```sql
SELECT 
  w.word,
  SUM(w.frequency) as total_frequency,
  COUNT(DISTINCT w.lyrics_id) as song_count
FROM `${PROJECT_ID}.lyrics_analysis.word_frequency` w
WHERE w.is_stopword = FALSE 
  AND LENGTH(w.word) >= 3
GROUP BY w.word
ORDER BY total_frequency DESC
LIMIT 50
```

## Deployment e Manutenção

### Processo de Deploy
1. **Criar conexão BigQuery** no Data Studio
2. **Importar templates** de dashboard
3. **Configurar filtros** e parâmetros
4. **Testar interatividade** e performance
5. **Publicar** para usuários finais

### Manutenção Regular
- **Revisão mensal** de métricas e KPIs
- **Otimização trimestral** de queries
- **Atualização semestral** de visualizações
- **Backup anual** de configurações

### Versionamento
- **Git** para templates e configurações
- **Changelog** para mudanças significativas
- **Rollback** para versões anteriores se necessário

