# Propostas de Gráficos para Looker - Pipeline de Análise de Letras

## Dashboard 1: Visão Geral Executiva

### 1. Single Value Cards (KPIs Principais)
```sql
-- Total de Músicas
SELECT COUNT(DISTINCT id) as total_songs
FROM `${project}.lyrics_analysis.raw_lyrics`
WHERE lyrics IS NOT NULL

-- Sentimento Médio Global
SELECT ROUND(AVG(sentiment_score), 3) as avg_sentiment
FROM `${project}.lyrics_analysis.sentiment_analysis`

-- Artistas Únicos
SELECT COUNT(DISTINCT artist) as total_artists
FROM `${project}.lyrics_analysis.raw_lyrics`
WHERE artist != 'Unknown'

-- Score de Legibilidade Médio
SELECT ROUND(AVG(readability_score), 1) as avg_readability
FROM `${project}.lyrics_analysis.processed_lyrics`
```

**Configuração Looker:**
- Tipo: Single Value
- Formato: Números grandes com ícones
- Cores: Verde para positivos, azul para neutros

### 2. Gráfico de Linha: Evolução Temporal do Sentimento
```sql
SELECT 
  year,
  AVG(sentiment_score) as avg_sentiment,
  COUNT(*) as song_count,
  STDDEV(sentiment_score) as sentiment_variation
FROM `${project}.lyrics_analysis.raw_lyrics` r
JOIN `${project}.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
WHERE year IS NOT NULL 
  AND year BETWEEN 1960 AND 2024
GROUP BY year
HAVING song_count >= 5
ORDER BY year
```

**Configuração Looker:**
- Tipo: Line Chart
- X-axis: year
- Y-axis: avg_sentiment
- Série secundária: song_count (bar chart)
- Filtros: Período de anos, gênero
- Drill-down: Por mês/trimestre

### 3. Gráfico de Barras Horizontais: Top 15 Gêneros por Volume
```sql
SELECT 
  genre,
  COUNT(*) as song_count,
  AVG(sentiment_score) as avg_sentiment,
  AVG(readability_score) as avg_readability
FROM `${project}.lyrics_analysis.raw_lyrics` r
JOIN `${project}.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
JOIN `${project}.lyrics_analysis.processed_lyrics` p ON r.id = p.id
WHERE genre != 'Unknown' AND genre IS NOT NULL
GROUP BY genre
HAVING song_count >= 20
ORDER BY song_count DESC
LIMIT 15
```

**Configuração Looker:**
- Tipo: Horizontal Bar Chart
- X-axis: song_count
- Y-axis: genre
- Cor por: avg_sentiment (gradiente verde-vermelho)
- Tooltip: avg_readability, song_count
- Drill-down: Para artistas do gênero

## Dashboard 2: Análise de Sentimentos

### 4. Donut Chart: Distribuição de Sentimentos
```sql
SELECT 
  sentiment_label,
  COUNT(*) as count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) as percentage
FROM `${project}.lyrics_analysis.sentiment_analysis`
GROUP BY sentiment_label
ORDER BY count DESC
```

**Configuração Looker:**
- Tipo: Donut Chart
- Dimensão: sentiment_label
- Métrica: count
- Cores: Verde (positive), Vermelho (negative), Cinza (neutral)
- Centro: Total de análises

### 5. Heatmap: Sentimento por Gênero e Década
```sql
SELECT 
  genre,
  FLOOR(year / 10) * 10 as decade,
  AVG(sentiment_score) as avg_sentiment,
  COUNT(*) as song_count
FROM `${project}.lyrics_analysis.raw_lyrics` r
JOIN `${project}.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
WHERE year IS NOT NULL 
  AND year BETWEEN 1970 AND 2020
  AND genre != 'Unknown'
GROUP BY genre, decade
HAVING song_count >= 10
ORDER BY genre, decade
```

**Configuração Looker:**
- Tipo: Heatmap
- X-axis: decade
- Y-axis: genre
- Cor: avg_sentiment
- Escala: -1 (vermelho) a +1 (verde)
- Tooltip: song_count, avg_sentiment

### 6. Scatter Plot: Correlação Sentimento vs Legibilidade
```sql
SELECT 
  r.title,
  r.artist,
  r.genre,
  s.sentiment_score,
  p.readability_score,
  p.word_count
FROM `${project}.lyrics_analysis.raw_lyrics` r
JOIN `${project}.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
JOIN `${project}.lyrics_analysis.processed_lyrics` p ON r.id = p.id
WHERE s.sentiment_score IS NOT NULL 
  AND p.readability_score IS NOT NULL
```

**Configuração Looker:**
- Tipo: Scatter Plot
- X-axis: readability_score
- Y-axis: sentiment_score
- Tamanho: word_count
- Cor: genre
- Filtros: Artista, gênero, período
- Tooltip: title, artist

## Dashboard 3: Análise de Palavras

### 7. Word Cloud: Palavras Mais Frequentes
```sql
SELECT 
  word,
  SUM(frequency) as total_frequency,
  COUNT(DISTINCT lyrics_id) as songs_with_word
FROM `${project}.lyrics_analysis.word_frequency`
WHERE is_stopword = FALSE 
  AND LENGTH(word) >= 3
  AND word NOT IN ('yeah', 'ohh', 'ahh', 'mmm')
GROUP BY word
HAVING songs_with_word >= 10
ORDER BY total_frequency DESC
LIMIT 100
```

**Configuração Looker:**
- Tipo: Word Cloud (se disponível) ou Table
- Tamanho da palavra: total_frequency
- Filtros: Sentimento, gênero, período
- Drill-down: Músicas que contêm a palavra

### 8. Gráfico de Área Empilhada: Evolução de Palavras-Chave
```sql
WITH target_words AS (
  SELECT word FROM UNNEST(['love', 'heart', 'time', 'life', 'world', 'money', 'party']) as word
),
word_trends AS (
  SELECT 
    r.year,
    w.word,
    SUM(w.frequency) as total_frequency
  FROM `${project}.lyrics_analysis.word_frequency` w
  JOIN `${project}.lyrics_analysis.raw_lyrics` r ON w.lyrics_id = r.id
  JOIN target_words tw ON LOWER(w.word) = LOWER(tw.word)
  WHERE r.year IS NOT NULL 
    AND r.year BETWEEN 1980 AND 2024
  GROUP BY r.year, w.word
)
SELECT * FROM word_trends
ORDER BY year, word
```

**Configuração Looker:**
- Tipo: Area Chart (Stacked)
- X-axis: year
- Y-axis: total_frequency
- Série: word
- Cores: Paleta distinta para cada palavra
- Filtros: Palavras específicas

### 9. Treemap: Artistas por Volume e Sentimento
```sql
SELECT 
  artist,
  COUNT(*) as song_count,
  AVG(sentiment_score) as avg_sentiment,
  STRING_AGG(DISTINCT genre, ', ') as genres
FROM `${project}.lyrics_analysis.raw_lyrics` r
JOIN `${project}.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
WHERE artist != 'Unknown'
GROUP BY artist
HAVING song_count >= 5
ORDER BY song_count DESC
LIMIT 50
```

**Configuração Looker:**
- Tipo: Treemap
- Tamanho: song_count
- Cor: avg_sentiment
- Label: artist
- Tooltip: genres, song_count, avg_sentiment

## Dashboard 4: Análise de Complexidade

### 10. Histograma: Distribuição de Contagem de Palavras
```sql
SELECT 
  CASE 
    WHEN word_count < 50 THEN '< 50'
    WHEN word_count < 100 THEN '50-99'
    WHEN word_count < 150 THEN '100-149'
    WHEN word_count < 200 THEN '150-199'
    WHEN word_count < 300 THEN '200-299'
    ELSE '300+'
  END as word_count_range,
  COUNT(*) as song_count
FROM `${project}.lyrics_analysis.processed_lyrics`
WHERE word_count IS NOT NULL
GROUP BY word_count_range
ORDER BY 
  CASE word_count_range
    WHEN '< 50' THEN 1
    WHEN '50-99' THEN 2
    WHEN '100-149' THEN 3
    WHEN '150-199' THEN 4
    WHEN '200-299' THEN 5
    WHEN '300+' THEN 6
  END
```

**Configuração Looker:**
- Tipo: Column Chart
- X-axis: word_count_range
- Y-axis: song_count
- Cor: Gradiente azul
- Filtros: Gênero, período

### 11. Box Plot: Legibilidade por Gênero
```sql
SELECT 
  genre,
  readability_score,
  COUNT(*) as song_count
FROM `${project}.lyrics_analysis.raw_lyrics` r
JOIN `${project}.lyrics_analysis.processed_lyrics` p ON r.id = p.id
WHERE genre != 'Unknown' 
  AND readability_score IS NOT NULL
GROUP BY genre, readability_score
HAVING COUNT(*) >= 1
ORDER BY genre, readability_score
```

**Configuração Looker:**
- Tipo: Box Plot (ou Violin Plot se disponível)
- X-axis: genre
- Y-axis: readability_score
- Estatísticas: Mediana, quartis, outliers

### 12. Radar Chart: Perfil de Complexidade por Década
```sql
SELECT 
  FLOOR(year / 10) * 10 as decade,
  AVG(word_count) as avg_word_count,
  AVG(unique_words) as avg_unique_words,
  AVG(avg_word_length) as avg_word_length,
  AVG(readability_score) as avg_readability,
  AVG(unique_words / word_count) as vocabulary_diversity
FROM `${project}.lyrics_analysis.raw_lyrics` r
JOIN `${project}.lyrics_analysis.processed_lyrics` p ON r.id = p.id
WHERE year IS NOT NULL 
  AND year BETWEEN 1960 AND 2020
  AND word_count > 0
GROUP BY decade
ORDER BY decade
```

**Configuração Looker:**
- Tipo: Radar Chart
- Dimensões: Métricas normalizadas (0-100)
- Séries: decade
- Eixos: avg_word_count, avg_readability, vocabulary_diversity

## Dashboard 5: Análise Comparativa

### 13. Gráfico de Barras Agrupadas: Top Artistas Multi-Métrica
```sql
SELECT 
  artist,
  COUNT(*) as song_count,
  AVG(sentiment_score) as avg_sentiment,
  AVG(readability_score) as avg_readability,
  AVG(word_count) as avg_word_count
FROM `${project}.lyrics_analysis.raw_lyrics` r
JOIN `${project}.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
JOIN `${project}.lyrics_analysis.processed_lyrics` p ON r.id = p.id
WHERE artist != 'Unknown'
GROUP BY artist
HAVING song_count >= 10
ORDER BY song_count DESC
LIMIT 20
```

**Configuração Looker:**
- Tipo: Grouped Bar Chart
- X-axis: artist
- Y-axis: Múltiplas métricas (normalizadas)
- Séries: avg_sentiment, avg_readability, avg_word_count
- Filtros: Número mínimo de músicas

### 14. Sankey Diagram: Fluxo Gênero → Sentimento → Década
```sql
SELECT 
  genre,
  sentiment_label,
  FLOOR(year / 10) * 10 as decade,
  COUNT(*) as flow_count
FROM `${project}.lyrics_analysis.raw_lyrics` r
JOIN `${project}.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
WHERE genre != 'Unknown' 
  AND year IS NOT NULL 
  AND year BETWEEN 1980 AND 2020
GROUP BY genre, sentiment_label, decade
HAVING flow_count >= 5
ORDER BY genre, sentiment_label, decade
```

**Configuração Looker:**
- Tipo: Sankey Diagram
- Fluxo: genre → sentiment_label → decade
- Espessura: flow_count
- Cores: Por sentimento

### 15. Gráfico de Linhas Múltiplas: Tendências Comparativas
```sql
SELECT 
  year,
  AVG(CASE WHEN genre = 'Rock' THEN sentiment_score END) as rock_sentiment,
  AVG(CASE WHEN genre = 'Pop' THEN sentiment_score END) as pop_sentiment,
  AVG(CASE WHEN genre = 'Hip-Hop' THEN sentiment_score END) as hiphop_sentiment,
  AVG(CASE WHEN genre = 'Country' THEN sentiment_score END) as country_sentiment
FROM `${project}.lyrics_analysis.raw_lyrics` r
JOIN `${project}.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
WHERE year IS NOT NULL 
  AND year BETWEEN 1980 AND 2024
  AND genre IN ('Rock', 'Pop', 'Hip-Hop', 'Country')
GROUP BY year
HAVING COUNT(*) >= 10
ORDER BY year
```

**Configuração Looker:**
- Tipo: Multi-Line Chart
- X-axis: year
- Y-axis: sentiment scores
- Linhas: Por gênero
- Cores: Distintas para cada gênero

## Configurações Gerais do Looker

### Filtros Globais Recomendados:
1. **Período**: Date Range (year)
2. **Gênero**: Multi-select dropdown
3. **Artista**: Search box com autocomplete
4. **Sentimento**: Dropdown (Positive/Negative/Neutral/All)
5. **Volume mínimo**: Slider (mín. músicas por artista/gênero)

### Drill-downs Sugeridos:
- **Gênero** → **Artista** → **Música específica**
- **Ano** → **Trimestre** → **Mês**
- **Artista** → **Álbum** → **Música**
- **Palavra** → **Músicas que contêm** → **Contexto**

### Formatação e Cores:
```css
/* Paleta de cores para sentimentos */
Positivo: #4CAF50 (Verde)
Negativo: #F44336 (Vermelho)
Neutro: #9E9E9E (Cinza)

/* Paleta para gêneros */
Rock: #E91E63 (Rosa)
Pop: #2196F3 (Azul)
Hip-Hop: #FF9800 (Laranja)
Country: #795548 (Marrom)
Electronic: #9C27B0 (Roxo)

/* Gradientes */
Sentimento: Vermelho → Amarelo → Verde
Tempo: Azul escuro → Azul claro
```

### Métricas Calculadas no Looker:
```sql
-- Diversidade Vocabular
${unique_words} / NULLIF(${word_count}, 0)

-- Score Normalizado de Sentimento (0-100)
(${sentiment_score} + 1) * 50

-- Classificação de Legibilidade
CASE 
  WHEN ${readability_score} >= 80 THEN 'Muito Fácil'
  WHEN ${readability_score} >= 60 THEN 'Fácil'
  WHEN ${readability_score} >= 40 THEN 'Moderado'
  WHEN ${readability_score} >= 20 THEN 'Difícil'
  ELSE 'Muito Difícil'
END
```

Essas propostas aproveitam as capacidades específicas do Looker como interatividade, drill-downs e filtros dinâmicos, criando uma experiência rica de análise dos dados de letras de música!

