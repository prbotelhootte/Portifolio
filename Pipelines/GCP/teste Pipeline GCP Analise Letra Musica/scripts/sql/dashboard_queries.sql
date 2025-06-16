-- Queries SQL para Dashboards e Análises
-- Pipeline de Análise de Letras de Música

-- =====================================================
-- MÉTRICAS E KPIs PRINCIPAIS
-- =====================================================

-- 1. Visão Geral do Dataset
CREATE OR REPLACE VIEW `${PROJECT_ID}.lyrics_analysis.dataset_overview` AS
SELECT 
  COUNT(DISTINCT r.id) as total_songs,
  COUNT(DISTINCT r.artist) as total_artists,
  COUNT(DISTINCT r.genre) as total_genres,
  COUNT(DISTINCT r.year) as years_span,
  MIN(r.year) as earliest_year,
  MAX(r.year) as latest_year,
  AVG(p.word_count) as avg_words_per_song,
  AVG(p.readability_score) as avg_readability,
  AVG(s.sentiment_score) as avg_sentiment
FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r
LEFT JOIN `${PROJECT_ID}.lyrics_analysis.processed_lyrics` p ON r.id = p.id
LEFT JOIN `${PROJECT_ID}.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
WHERE r.lyrics IS NOT NULL AND r.lyrics != '';

-- 2. Top Artistas por Volume de Músicas
CREATE OR REPLACE VIEW `${PROJECT_ID}.lyrics_analysis.top_artists_by_volume` AS
SELECT 
  r.artist,
  COUNT(*) as song_count,
  AVG(p.word_count) as avg_word_count,
  AVG(p.readability_score) as avg_readability,
  AVG(s.sentiment_score) as avg_sentiment,
  MODE(s.sentiment_label) as dominant_sentiment,
  STRING_AGG(DISTINCT r.genre, ', ' ORDER BY r.genre) as genres
FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r
LEFT JOIN `${PROJECT_ID}.lyrics_analysis.processed_lyrics` p ON r.id = p.id
LEFT JOIN `${PROJECT_ID}.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
WHERE r.artist != 'Unknown' AND r.artist IS NOT NULL
GROUP BY r.artist
HAVING song_count >= 3
ORDER BY song_count DESC, avg_sentiment DESC
LIMIT 50;

-- 3. Análise de Sentimentos por Gênero
CREATE OR REPLACE VIEW `${PROJECT_ID}.lyrics_analysis.sentiment_by_genre` AS
SELECT 
  r.genre,
  COUNT(*) as song_count,
  AVG(s.sentiment_score) as avg_sentiment_score,
  STDDEV(s.sentiment_score) as sentiment_stddev,
  COUNTIF(s.sentiment_label = 'positive') / COUNT(*) * 100 as positive_percentage,
  COUNTIF(s.sentiment_label = 'negative') / COUNT(*) * 100 as negative_percentage,
  COUNTIF(s.sentiment_label = 'neutral') / COUNT(*) * 100 as neutral_percentage,
  AVG(s.confidence) as avg_confidence
FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r
JOIN `${PROJECT_ID}.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
WHERE r.genre != 'Unknown' AND r.genre IS NOT NULL
GROUP BY r.genre
HAVING song_count >= 10
ORDER BY avg_sentiment_score DESC;

-- 4. Evolução Temporal dos Sentimentos
CREATE OR REPLACE VIEW `${PROJECT_ID}.lyrics_analysis.sentiment_evolution` AS
SELECT 
  r.year,
  COUNT(*) as song_count,
  AVG(s.sentiment_score) as avg_sentiment,
  COUNTIF(s.sentiment_label = 'positive') / COUNT(*) * 100 as positive_pct,
  COUNTIF(s.sentiment_label = 'negative') / COUNT(*) * 100 as negative_pct,
  COUNTIF(s.sentiment_label = 'neutral') / COUNT(*) * 100 as neutral_pct,
  AVG(p.readability_score) as avg_readability,
  AVG(p.word_count) as avg_word_count
FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r
JOIN `${PROJECT_ID}.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
JOIN `${PROJECT_ID}.lyrics_analysis.processed_lyrics` p ON r.id = p.id
WHERE r.year IS NOT NULL 
  AND r.year BETWEEN 1950 AND 2024
GROUP BY r.year
HAVING song_count >= 5
ORDER BY r.year;

-- 5. Palavras Mais Frequentes Globalmente
CREATE OR REPLACE VIEW `${PROJECT_ID}.lyrics_analysis.global_word_frequency` AS
SELECT 
  w.word,
  SUM(w.frequency) as total_frequency,
  COUNT(DISTINCT w.lyrics_id) as songs_with_word,
  AVG(w.tf_idf) as avg_tfidf,
  MODE(w.pos_tag) as common_pos_tag,
  SUM(w.frequency) / COUNT(DISTINCT w.lyrics_id) as avg_frequency_per_song
FROM `${PROJECT_ID}.lyrics_analysis.word_frequency` w
WHERE w.is_stopword = FALSE 
  AND LENGTH(w.word) >= 3
  AND w.word NOT IN ('yeah', 'ohh', 'ahh', 'mmm', 'hmm')
GROUP BY w.word
HAVING songs_with_word >= 10
ORDER BY total_frequency DESC
LIMIT 100;

-- 6. Análise de Complexidade por Década
CREATE OR REPLACE VIEW `${PROJECT_ID}.lyrics_analysis.complexity_by_decade` AS
SELECT 
  FLOOR(r.year / 10) * 10 as decade,
  COUNT(*) as song_count,
  AVG(p.word_count) as avg_word_count,
  AVG(p.unique_words) as avg_unique_words,
  AVG(p.avg_word_length) as avg_word_length,
  AVG(p.readability_score) as avg_readability,
  STDDEV(p.readability_score) as readability_stddev,
  AVG(p.unique_words / p.word_count) as vocabulary_diversity
FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r
JOIN `${PROJECT_ID}.lyrics_analysis.processed_lyrics` p ON r.id = p.id
WHERE r.year IS NOT NULL 
  AND r.year BETWEEN 1950 AND 2024
  AND p.word_count > 0
GROUP BY decade
HAVING song_count >= 20
ORDER BY decade;

-- 7. Top Palavras por Sentimento
CREATE OR REPLACE VIEW `${PROJECT_ID}.lyrics_analysis.words_by_sentiment` AS
WITH sentiment_words AS (
  SELECT 
    w.word,
    s.sentiment_label,
    SUM(w.frequency) as total_frequency,
    COUNT(DISTINCT w.lyrics_id) as song_count,
    AVG(w.tf_idf) as avg_tfidf
  FROM `${PROJECT_ID}.lyrics_analysis.word_frequency` w
  JOIN `${PROJECT_ID}.lyrics_analysis.sentiment_analysis` s ON w.lyrics_id = s.lyrics_id
  WHERE w.is_stopword = FALSE 
    AND LENGTH(w.word) >= 3
    AND s.sentiment_label IN ('positive', 'negative')
  GROUP BY w.word, s.sentiment_label
  HAVING song_count >= 5
)
SELECT 
  sentiment_label,
  word,
  total_frequency,
  song_count,
  avg_tfidf,
  ROW_NUMBER() OVER (PARTITION BY sentiment_label ORDER BY total_frequency DESC) as rank
FROM sentiment_words
QUALIFY rank <= 50
ORDER BY sentiment_label, rank;

-- 8. Artistas Mais Prolíficos por Década
CREATE OR REPLACE VIEW `${PROJECT_ID}.lyrics_analysis.prolific_artists_by_decade` AS
SELECT 
  FLOOR(r.year / 10) * 10 as decade,
  r.artist,
  COUNT(*) as song_count,
  AVG(p.word_count) as avg_word_count,
  AVG(s.sentiment_score) as avg_sentiment,
  STRING_AGG(DISTINCT r.genre, ', ' ORDER BY r.genre) as genres
FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r
JOIN `${PROJECT_ID}.lyrics_analysis.processed_lyrics` p ON r.id = p.id
JOIN `${PROJECT_ID}.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
WHERE r.year IS NOT NULL 
  AND r.year BETWEEN 1950 AND 2024
  AND r.artist != 'Unknown'
GROUP BY decade, r.artist
HAVING song_count >= 5
ORDER BY decade DESC, song_count DESC;

-- =====================================================
-- QUERIES PARA ANÁLISES ESPECÍFICAS
-- =====================================================

-- 9. Correlação entre Legibilidade e Sentimento
CREATE OR REPLACE VIEW `${PROJECT_ID}.lyrics_analysis.readability_sentiment_correlation` AS
SELECT 
  CASE 
    WHEN p.readability_score >= 80 THEN 'Very Easy'
    WHEN p.readability_score >= 60 THEN 'Easy'
    WHEN p.readability_score >= 40 THEN 'Moderate'
    WHEN p.readability_score >= 20 THEN 'Hard'
    ELSE 'Very Hard'
  END as readability_level,
  COUNT(*) as song_count,
  AVG(s.sentiment_score) as avg_sentiment,
  AVG(p.word_count) as avg_word_count,
  AVG(p.unique_words) as avg_unique_words,
  COUNTIF(s.sentiment_label = 'positive') / COUNT(*) * 100 as positive_pct
FROM `${PROJECT_ID}.lyrics_analysis.processed_lyrics` p
JOIN `${PROJECT_ID}.lyrics_analysis.sentiment_analysis` s ON p.id = s.lyrics_id
WHERE p.readability_score IS NOT NULL
GROUP BY readability_level
ORDER BY 
  CASE readability_level
    WHEN 'Very Easy' THEN 1
    WHEN 'Easy' THEN 2
    WHEN 'Moderate' THEN 3
    WHEN 'Hard' THEN 4
    WHEN 'Very Hard' THEN 5
  END;

-- 10. Análise de Diversidade Vocabular por Gênero
CREATE OR REPLACE VIEW `${PROJECT_ID}.lyrics_analysis.vocabulary_diversity_by_genre` AS
SELECT 
  r.genre,
  COUNT(*) as song_count,
  AVG(p.unique_words) as avg_unique_words,
  AVG(p.word_count) as avg_total_words,
  AVG(p.unique_words / NULLIF(p.word_count, 0)) as avg_vocabulary_diversity,
  STDDEV(p.unique_words / NULLIF(p.word_count, 0)) as diversity_stddev,
  AVG(p.avg_word_length) as avg_word_length
FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r
JOIN `${PROJECT_ID}.lyrics_analysis.processed_lyrics` p ON r.id = p.id
WHERE r.genre != 'Unknown' 
  AND r.genre IS NOT NULL
  AND p.word_count > 0
GROUP BY r.genre
HAVING song_count >= 15
ORDER BY avg_vocabulary_diversity DESC;

-- 11. Tendências de Palavras ao Longo do Tempo
CREATE OR REPLACE FUNCTION `${PROJECT_ID}.lyrics_analysis.get_word_trend`(target_word STRING)
RETURNS TABLE<year INT64, frequency INT64, song_count INT64, avg_tfidf FLOAT64>
AS (
  SELECT 
    r.year,
    SUM(w.frequency) as frequency,
    COUNT(DISTINCT w.lyrics_id) as song_count,
    AVG(w.tf_idf) as avg_tfidf
  FROM `${PROJECT_ID}.lyrics_analysis.word_frequency` w
  JOIN `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r ON w.lyrics_id = r.id
  WHERE LOWER(w.word) = LOWER(target_word)
    AND r.year IS NOT NULL
    AND r.year BETWEEN 1950 AND 2024
  GROUP BY r.year
  HAVING song_count >= 2
  ORDER BY r.year
);

-- 12. Comparação de Artistas Similares
CREATE OR REPLACE VIEW `${PROJECT_ID}.lyrics_analysis.artist_similarity_metrics` AS
WITH artist_metrics AS (
  SELECT 
    r.artist,
    AVG(p.word_count) as avg_word_count,
    AVG(p.unique_words) as avg_unique_words,
    AVG(p.readability_score) as avg_readability,
    AVG(s.sentiment_score) as avg_sentiment,
    AVG(p.avg_word_length) as avg_word_length,
    COUNT(*) as song_count
  FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r
  JOIN `${PROJECT_ID}.lyrics_analysis.processed_lyrics` p ON r.id = p.id
  JOIN `${PROJECT_ID}.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
  WHERE r.artist != 'Unknown' AND r.artist IS NOT NULL
  GROUP BY r.artist
  HAVING song_count >= 5
)
SELECT 
  a1.artist as artist1,
  a2.artist as artist2,
  ABS(a1.avg_sentiment - a2.avg_sentiment) as sentiment_diff,
  ABS(a1.avg_readability - a2.avg_readability) as readability_diff,
  ABS(a1.avg_word_count - a2.avg_word_count) as word_count_diff,
  -- Similarity score (lower is more similar)
  (ABS(a1.avg_sentiment - a2.avg_sentiment) + 
   ABS(a1.avg_readability - a2.avg_readability) / 100 + 
   ABS(a1.avg_word_count - a2.avg_word_count) / 1000) as similarity_score
FROM artist_metrics a1
CROSS JOIN artist_metrics a2
WHERE a1.artist < a2.artist  -- Avoid duplicates
ORDER BY similarity_score
LIMIT 100;

-- =====================================================
-- QUERIES PARA DASHBOARDS ESPECÍFICOS
-- =====================================================

-- 13. Dashboard Principal - Métricas em Tempo Real
CREATE OR REPLACE VIEW `${PROJECT_ID}.lyrics_analysis.dashboard_main_metrics` AS
SELECT 
  'total_songs' as metric_name,
  COUNT(DISTINCT r.id) as metric_value,
  'count' as metric_type,
  CURRENT_TIMESTAMP() as last_updated
FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r
WHERE r.lyrics IS NOT NULL

UNION ALL

SELECT 
  'total_artists' as metric_name,
  COUNT(DISTINCT r.artist) as metric_value,
  'count' as metric_type,
  CURRENT_TIMESTAMP() as last_updated
FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r
WHERE r.artist != 'Unknown' AND r.artist IS NOT NULL

UNION ALL

SELECT 
  'avg_sentiment' as metric_name,
  ROUND(AVG(s.sentiment_score), 3) as metric_value,
  'average' as metric_type,
  CURRENT_TIMESTAMP() as last_updated
FROM `${PROJECT_ID}.lyrics_analysis.sentiment_analysis` s

UNION ALL

SELECT 
  'avg_readability' as metric_name,
  ROUND(AVG(p.readability_score), 1) as metric_value,
  'average' as metric_type,
  CURRENT_TIMESTAMP() as last_updated
FROM `${PROJECT_ID}.lyrics_analysis.processed_lyrics` p
WHERE p.readability_score IS NOT NULL;

-- 14. Dashboard de Tendências - Dados para Gráficos
CREATE OR REPLACE VIEW `${PROJECT_ID}.lyrics_analysis.dashboard_trends` AS
SELECT 
  'sentiment_by_year' as chart_type,
  CAST(r.year AS STRING) as dimension,
  AVG(s.sentiment_score) as value,
  COUNT(*) as count
FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r
JOIN `${PROJECT_ID}.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
WHERE r.year IS NOT NULL AND r.year BETWEEN 1980 AND 2024
GROUP BY r.year
HAVING count >= 5

UNION ALL

SELECT 
  'readability_by_year' as chart_type,
  CAST(r.year AS STRING) as dimension,
  AVG(p.readability_score) as value,
  COUNT(*) as count
FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r
JOIN `${PROJECT_ID}.lyrics_analysis.processed_lyrics` p ON r.id = p.id
WHERE r.year IS NOT NULL AND r.year BETWEEN 1980 AND 2024
GROUP BY r.year
HAVING count >= 5

UNION ALL

SELECT 
  'word_count_by_year' as chart_type,
  CAST(r.year AS STRING) as dimension,
  AVG(p.word_count) as value,
  COUNT(*) as count
FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r
JOIN `${PROJECT_ID}.lyrics_analysis.processed_lyrics` p ON r.id = p.id
WHERE r.year IS NOT NULL AND r.year BETWEEN 1980 AND 2024
GROUP BY r.year
HAVING count >= 5;

-- 15. Dashboard de Gêneros - Comparação
CREATE OR REPLACE VIEW `${PROJECT_ID}.lyrics_analysis.dashboard_genre_comparison` AS
SELECT 
  r.genre,
  COUNT(*) as song_count,
  AVG(s.sentiment_score) as avg_sentiment,
  AVG(p.readability_score) as avg_readability,
  AVG(p.word_count) as avg_word_count,
  AVG(p.unique_words) as avg_unique_words,
  COUNTIF(s.sentiment_label = 'positive') / COUNT(*) * 100 as positive_percentage,
  COUNTIF(s.sentiment_label = 'negative') / COUNT(*) * 100 as negative_percentage
FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r
JOIN `${PROJECT_ID}.lyrics_analysis.processed_lyrics` p ON r.id = p.id
JOIN `${PROJECT_ID}.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
WHERE r.genre != 'Unknown' AND r.genre IS NOT NULL
GROUP BY r.genre
HAVING song_count >= 20
ORDER BY song_count DESC;

-- =====================================================
-- PROCEDURES PARA ANÁLISES AVANÇADAS
-- =====================================================

-- 16. Procedure para Análise de Artista Específico
CREATE OR REPLACE PROCEDURE `${PROJECT_ID}.lyrics_analysis.analyze_artist`(
  artist_name STRING
)
BEGIN
  DECLARE song_count INT64;
  
  -- Verificar se artista existe
  SELECT COUNT(*) INTO song_count
  FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics`
  WHERE LOWER(artist) = LOWER(artist_name);
  
  IF song_count = 0 THEN
    SELECT "Artista não encontrado" as message;
    RETURN;
  END IF;
  
  -- Retornar análise completa do artista
  SELECT 
    r.artist,
    COUNT(*) as total_songs,
    AVG(p.word_count) as avg_word_count,
    AVG(p.unique_words) as avg_unique_words,
    AVG(p.readability_score) as avg_readability,
    AVG(s.sentiment_score) as avg_sentiment,
    MODE(s.sentiment_label) as dominant_sentiment,
    STRING_AGG(DISTINCT r.genre, ', ') as genres,
    MIN(r.year) as earliest_year,
    MAX(r.year) as latest_year
  FROM `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r
  JOIN `${PROJECT_ID}.lyrics_analysis.processed_lyrics` p ON r.id = p.id
  JOIN `${PROJECT_ID}.lyrics_analysis.sentiment_analysis` s ON r.id = s.lyrics_id
  WHERE LOWER(r.artist) = LOWER(artist_name)
  GROUP BY r.artist;
  
  -- Top palavras do artista
  SELECT 
    w.word,
    SUM(w.frequency) as total_frequency,
    AVG(w.tf_idf) as avg_tfidf
  FROM `${PROJECT_ID}.lyrics_analysis.word_frequency` w
  JOIN `${PROJECT_ID}.lyrics_analysis.raw_lyrics` r ON w.lyrics_id = r.id
  WHERE LOWER(r.artist) = LOWER(artist_name)
    AND w.is_stopword = FALSE
    AND LENGTH(w.word) >= 3
  GROUP BY w.word
  ORDER BY total_frequency DESC
  LIMIT 20;
END;

