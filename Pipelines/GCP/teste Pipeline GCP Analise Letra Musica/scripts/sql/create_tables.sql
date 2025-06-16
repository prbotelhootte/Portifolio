-- Criação das tabelas BigQuery para o pipeline de análise de letras

-- Dataset principal
CREATE SCHEMA IF NOT EXISTS `${PROJECT_ID}.lyrics_analysis`
OPTIONS (
  description = "Dataset para análise de letras de música",
  location = "US"
);

-- Tabela de letras brutas
CREATE OR REPLACE TABLE `${PROJECT_ID}.lyrics_analysis.raw_lyrics` (
  id STRING NOT NULL,
  title STRING,
  artist STRING,
  album STRING,
  genre STRING,
  year INT64,
  lyrics STRING,
  source STRING,
  created_at TIMESTAMP,
  file_path STRING
)
PARTITION BY DATE(created_at)
CLUSTER BY artist, genre
OPTIONS (
  description = "Dados brutos de letras de música",
  partition_expiration_days = 365
);

-- Tabela de letras processadas
CREATE OR REPLACE TABLE `${PROJECT_ID}.lyrics_analysis.processed_lyrics` (
  id STRING NOT NULL,
  title STRING,
  artist STRING,
  word_count INT64,
  unique_words INT64,
  avg_word_length FLOAT64,
  readability_score FLOAT64,
  language STRING,
  processed_text STRING,
  tokens STRING, -- JSON array as string
  processed_at TIMESTAMP
)
PARTITION BY DATE(processed_at)
CLUSTER BY artist, language
OPTIONS (
  description = "Letras processadas com métricas NLP"
);

-- Tabela de frequência de palavras
CREATE OR REPLACE TABLE `${PROJECT_ID}.lyrics_analysis.word_frequency` (
  lyrics_id STRING NOT NULL,
  word STRING NOT NULL,
  frequency INT64,
  tf_idf FLOAT64,
  pos_tag STRING,
  is_stopword BOOLEAN,
  created_at TIMESTAMP
)
PARTITION BY DATE(created_at)
CLUSTER BY word, lyrics_id
OPTIONS (
  description = "Frequência e análise de palavras por música"
);

-- Tabela de análise de sentimentos
CREATE OR REPLACE TABLE `${PROJECT_ID}.lyrics_analysis.sentiment_analysis` (
  lyrics_id STRING NOT NULL,
  sentiment_score FLOAT64,
  sentiment_label STRING,
  confidence FLOAT64,
  positive_words STRING, -- JSON array
  negative_words STRING, -- JSON array
  neutral_words STRING,  -- JSON array
  analyzed_at TIMESTAMP
)
PARTITION BY DATE(analyzed_at)
CLUSTER BY sentiment_label, lyrics_id
OPTIONS (
  description = "Análise de sentimentos das letras"
);

-- Views para análises

-- View: Estatísticas por artista
CREATE OR REPLACE VIEW `${PROJECT_ID}.lyrics_analysis.artist_stats` AS
SELECT 
  p.artist,
  COUNT(*) as total_songs,
  AVG(p.word_count) as avg_word_count,
  AVG(p.unique_words) as avg_unique_words,
  AVG(p.readability_score) as avg_readability,
  AVG(s.sentiment_score) as avg_sentiment,
  MODE(s.sentiment_label) as dominant_sentiment
FROM `${PROJECT_ID}.lyrics_analysis.processed_lyrics` p
LEFT JOIN `${PROJECT_ID}.lyrics_analysis.sentiment_analysis` s
  ON p.id = s.lyrics_id
WHERE p.artist != 'Unknown'
GROUP BY p.artist
HAVING total_songs >= 3
ORDER BY total_songs DESC;

-- View: Palavras mais frequentes globalmente
CREATE OR REPLACE VIEW `${PROJECT_ID}.lyrics_analysis.top_words_global` AS
SELECT 
  word,
  SUM(frequency) as total_frequency,
  COUNT(DISTINCT lyrics_id) as songs_count,
  AVG(tf_idf) as avg_tfidf,
  MODE(pos_tag) as common_pos_tag
FROM `${PROJECT_ID}.lyrics_analysis.word_frequency`
WHERE is_stopword = FALSE
  AND LENGTH(word) >= 3
GROUP BY word
HAVING songs_count >= 5
ORDER BY total_frequency DESC
LIMIT 1000;

-- View: Evolução temporal dos sentimentos
CREATE OR REPLACE VIEW `${PROJECT_ID}.lyrics_analysis.sentiment_trends` AS
SELECT 
  r.year,
  r.genre,
  COUNT(*) as songs_count,
  AVG(s.sentiment_score) as avg_sentiment,
  COUNTIF(s.sentiment_label = 'positive') / COUNT(*) as positive_ratio,
  COUNTIF(s.sentiment_label = 'negative') / COUNT(*) as negative_ratio,
  COUNTIF(s.sentiment_label = 'neutral') / COUNT(*) as neutral_ratio
FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r
JOIN `${PROJECT_ID}.lyrics_analysis.sentiment_analysis` s
  ON r.id = s.lyrics_id
WHERE r.year IS NOT NULL 
  AND r.year BETWEEN 1950 AND 2024
  AND r.genre != 'Unknown'
GROUP BY r.year, r.genre
HAVING songs_count >= 10
ORDER BY r.year DESC, r.genre;

-- View: Análise de complexidade por gênero
CREATE OR REPLACE VIEW `${PROJECT_ID}.lyrics_analysis.genre_complexity` AS
SELECT 
  r.genre,
  COUNT(*) as songs_count,
  AVG(p.word_count) as avg_word_count,
  AVG(p.unique_words) as avg_unique_words,
  AVG(p.avg_word_length) as avg_word_length,
  AVG(p.readability_score) as avg_readability,
  STDDEV(p.readability_score) as readability_stddev
FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r
JOIN `${PROJECT_ID}.lyrics_analysis.processed_lyrics` p
  ON r.id = p.id
WHERE r.genre != 'Unknown'
GROUP BY r.genre
HAVING songs_count >= 20
ORDER BY avg_readability DESC;

-- Função para calcular similaridade entre letras
CREATE OR REPLACE FUNCTION `${PROJECT_ID}.lyrics_analysis.calculate_similarity`(
  lyrics_id1 STRING,
  lyrics_id2 STRING
)
RETURNS FLOAT64
LANGUAGE js AS """
  // Função JavaScript para calcular similaridade de Jaccard
  // Esta é uma implementação simplificada
  return 0.5; // Placeholder - implementação real seria mais complexa
""";

-- Procedimento para limpeza de dados antigos
CREATE OR REPLACE PROCEDURE `${PROJECT_ID}.lyrics_analysis.cleanup_old_data`(
  days_to_keep INT64
)
BEGIN
  DECLARE cutoff_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL days_to_keep DAY);
  
  -- Deletar dados antigos das tabelas particionadas
  DELETE FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics`
  WHERE DATE(created_at) < cutoff_date;
  
  DELETE FROM `${PROJECT_ID}.lyrics_analysis.processed_lyrics`
  WHERE DATE(processed_at) < cutoff_date;
  
  DELETE FROM `${PROJECT_ID}.lyrics_analysis.word_frequency`
  WHERE DATE(created_at) < cutoff_date;
  
  DELETE FROM `${PROJECT_ID}.lyrics_analysis.sentiment_analysis`
  WHERE DATE(analyzed_at) < cutoff_date;
  
  SELECT FORMAT("Dados anteriores a %s foram removidos", cutoff_date) as message;
END;

