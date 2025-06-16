"""
Pipeline ETL para Análise de Letras de Música - GCP
Módulo principal de processamento de dados
"""

import os
import json
import logging
import pandas as pd
import numpy as np
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import re
from pathlib import Path

# NLP Libraries
import nltk
from nltk.corpus import stopwords
from nltk.tokenize import word_tokenize, sent_tokenize
from nltk.stem import PorterStemmer
from nltk.tag import pos_tag
from nltk.sentiment import SentimentIntensityAnalyzer

# ML Libraries
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

# GCP Libraries
from google.cloud import storage
from google.cloud import bigquery
from google.cloud import logging as cloud_logging

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class LyricsETLProcessor:
    """
    Classe principal para processamento ETL de letras de música
    """
    
    def __init__(self, project_id: str, dataset_id: str, bucket_name: str):
        """
        Inicializa o processador ETL
        
        Args:
            project_id: ID do projeto GCP
            dataset_id: ID do dataset BigQuery
            bucket_name: Nome do bucket Cloud Storage
        """
        self.project_id = project_id
        self.dataset_id = dataset_id
        self.bucket_name = bucket_name
        
        # Inicializar clientes GCP
        self.storage_client = storage.Client(project=project_id)
        self.bq_client = bigquery.Client(project=project_id)
        self.bucket = self.storage_client.bucket(bucket_name)
        
        # Configurar logging na nuvem
        cloud_logging_client = cloud_logging.Client(project=project_id)
        cloud_logging_client.setup_logging()
        
        # Inicializar componentes NLP
        self._setup_nltk()
        
        # Configurar TF-IDF
        self.tfidf_vectorizer = TfidfVectorizer(
            max_features=5000,
            stop_words='english',
            ngram_range=(1, 2),
            min_df=2,
            max_df=0.95
        )
        
        logger.info(f"ETL Processor inicializado para projeto {project_id}")
    
    def _setup_nltk(self):
        """Configura e baixa recursos necessários do NLTK"""
        try:
            nltk.data.find('tokenizers/punkt')
        except LookupError:
            nltk.download('punkt')
            
        try:
            nltk.data.find('corpora/stopwords')
        except LookupError:
            nltk.download('stopwords')
            
        try:
            nltk.data.find('taggers/averaged_perceptron_tagger')
        except LookupError:
            nltk.download('averaged_perceptron_tagger')
            
        try:
            nltk.data.find('vader_lexicon')
        except LookupError:
            nltk.download('vader_lexicon')
        
        # Inicializar componentes
        self.stemmer = PorterStemmer()
        self.sentiment_analyzer = SentimentIntensityAnalyzer()
        self.stop_words = set(stopwords.words('english'))
        
        logger.info("Recursos NLTK configurados com sucesso")
    
    def extract_from_storage(self, prefix: str = "raw-data/") -> List[Dict]:
        """
        Extrai dados do Cloud Storage
        
        Args:
            prefix: Prefixo dos arquivos a serem processados
            
        Returns:
            Lista de dicionários com dados das letras
        """
        logger.info(f"Iniciando extração de dados do bucket {self.bucket_name}")
        
        lyrics_data = []
        blobs = self.bucket.list_blobs(prefix=prefix)
        
        for blob in blobs:
            if blob.name.endswith(('.txt', '.json', '.csv')):
                try:
                    content = blob.download_as_text()
                    file_data = self._parse_file_content(blob.name, content)
                    if file_data:
                        lyrics_data.extend(file_data)
                        logger.info(f"Processado arquivo: {blob.name}")
                except Exception as e:
                    logger.error(f"Erro ao processar {blob.name}: {str(e)}")
        
        logger.info(f"Extraídos {len(lyrics_data)} registros de letras")
        return lyrics_data
    
    def _parse_file_content(self, filename: str, content: str) -> List[Dict]:
        """
        Analisa o conteúdo do arquivo baseado na extensão
        
        Args:
            filename: Nome do arquivo
            content: Conteúdo do arquivo
            
        Returns:
            Lista de dicionários com dados estruturados
        """
        file_extension = Path(filename).suffix.lower()
        
        try:
            if file_extension == '.json':
                return self._parse_json_content(content, filename)
            elif file_extension == '.csv':
                return self._parse_csv_content(content, filename)
            elif file_extension == '.txt':
                return self._parse_txt_content(content, filename)
        except Exception as e:
            logger.error(f"Erro ao analisar conteúdo de {filename}: {str(e)}")
            return []
    
    def _parse_json_content(self, content: str, filename: str) -> List[Dict]:
        """Analisa conteúdo JSON"""
        data = json.loads(content)
        
        if isinstance(data, list):
            return [self._normalize_lyrics_data(item, filename) for item in data]
        else:
            return [self._normalize_lyrics_data(data, filename)]
    
    def _parse_csv_content(self, content: str, filename: str) -> List[Dict]:
        """Analisa conteúdo CSV"""
        from io import StringIO
        df = pd.read_csv(StringIO(content))
        
        return [self._normalize_lyrics_data(row.to_dict(), filename) 
                for _, row in df.iterrows()]
    
    def _parse_txt_content(self, content: str, filename: str) -> List[Dict]:
        """Analisa conteúdo TXT simples"""
        # Assume formato simples: título na primeira linha, letra no resto
        lines = content.strip().split('\n')
        if len(lines) < 2:
            return []
        
        title = lines[0].strip()
        lyrics = '\n'.join(lines[1:]).strip()
        
        return [self._normalize_lyrics_data({
            'title': title,
            'lyrics': lyrics
        }, filename)]
    
    def _normalize_lyrics_data(self, data: Dict, filename: str) -> Dict:
        """
        Normaliza dados de entrada para formato padrão
        
        Args:
            data: Dados brutos
            filename: Nome do arquivo fonte
            
        Returns:
            Dicionário normalizado
        """
        normalized = {
            'id': data.get('id', self._generate_id(data, filename)),
            'title': data.get('title', data.get('song', 'Unknown')),
            'artist': data.get('artist', data.get('singer', 'Unknown')),
            'album': data.get('album', 'Unknown'),
            'genre': data.get('genre', 'Unknown'),
            'year': self._parse_year(data.get('year', data.get('release_year'))),
            'lyrics': data.get('lyrics', data.get('text', '')),
            'source': filename,
            'created_at': datetime.utcnow().isoformat(),
            'file_path': filename
        }
        
        return normalized
    
    def _generate_id(self, data: Dict, filename: str) -> str:
        """Gera ID único para a música"""
        title = data.get('title', data.get('song', 'unknown'))
        artist = data.get('artist', data.get('singer', 'unknown'))
        
        # Criar hash baseado em título, artista e filename
        import hashlib
        content = f"{title}_{artist}_{filename}".lower()
        return hashlib.md5(content.encode()).hexdigest()
    
    def _parse_year(self, year_value) -> Optional[int]:
        """Converte valor de ano para inteiro"""
        if year_value is None:
            return None
        
        try:
            if isinstance(year_value, str):
                # Extrair ano de strings como "2020-01-01" ou "2020"
                year_match = re.search(r'\b(19|20)\d{2}\b', year_value)
                if year_match:
                    return int(year_match.group())
            return int(year_value)
        except (ValueError, TypeError):
            return None
    
    def transform_lyrics(self, lyrics_data: List[Dict]) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
        """
        Aplica transformações NLP aos dados de letras
        
        Args:
            lyrics_data: Lista de dados de letras
            
        Returns:
            Tupla com DataFrames (processed_lyrics, word_frequency, sentiment_analysis)
        """
        logger.info("Iniciando transformações NLP")
        
        processed_lyrics = []
        word_frequency_data = []
        sentiment_data = []
        
        # Preparar corpus para TF-IDF
        corpus = [data['lyrics'] for data in lyrics_data if data['lyrics']]
        
        if corpus:
            tfidf_matrix = self.tfidf_vectorizer.fit_transform(corpus)
            feature_names = self.tfidf_vectorizer.get_feature_names_out()
        
        for i, lyrics_item in enumerate(lyrics_data):
            try:
                # Processar texto
                processed_text = self._clean_text(lyrics_item['lyrics'])
                tokens = self._tokenize_text(processed_text)
                
                # Análise básica
                word_count = len(tokens)
                unique_words = len(set(tokens))
                avg_word_length = np.mean([len(word) for word in tokens]) if tokens else 0
                
                # Análise de legibilidade (simplificada)
                readability_score = self._calculate_readability(lyrics_item['lyrics'])
                
                # Dados processados
                processed_lyrics.append({
                    'id': lyrics_item['id'],
                    'title': lyrics_item['title'],
                    'artist': lyrics_item['artist'],
                    'word_count': word_count,
                    'unique_words': unique_words,
                    'avg_word_length': avg_word_length,
                    'readability_score': readability_score,
                    'language': 'en',  # Assumindo inglês por simplicidade
                    'processed_text': processed_text,
                    'tokens': tokens,
                    'processed_at': datetime.utcnow().isoformat()
                })
                
                # Análise de frequência de palavras
                if i < len(corpus) and corpus:
                    word_freq = self._extract_word_frequency(
                        lyrics_item['id'], tokens, tfidf_matrix[i], feature_names
                    )
                    word_frequency_data.extend(word_freq)
                
                # Análise de sentimentos
                sentiment = self._analyze_sentiment(lyrics_item['lyrics'])
                sentiment['lyrics_id'] = lyrics_item['id']
                sentiment['analyzed_at'] = datetime.utcnow().isoformat()
                sentiment_data.append(sentiment)
                
            except Exception as e:
                logger.error(f"Erro ao processar letra {lyrics_item.get('id', 'unknown')}: {str(e)}")
        
        logger.info(f"Processadas {len(processed_lyrics)} letras")
        
        return (
            pd.DataFrame(processed_lyrics),
            pd.DataFrame(word_frequency_data),
            pd.DataFrame(sentiment_data)
        )
    
    def _clean_text(self, text: str) -> str:
        """Limpa e normaliza texto"""
        if not text:
            return ""
        
        # Converter para minúsculas
        text = text.lower()
        
        # Remover caracteres especiais, manter apenas letras, números e espaços
        text = re.sub(r'[^a-zA-Z0-9\s]', ' ', text)
        
        # Remover espaços múltiplos
        text = re.sub(r'\s+', ' ', text)
        
        return text.strip()
    
    def _tokenize_text(self, text: str) -> List[str]:
        """Tokeniza texto e remove stopwords"""
        if not text:
            return []
        
        # Tokenizar
        tokens = word_tokenize(text)
        
        # Filtrar tokens válidos e remover stopwords
        filtered_tokens = [
            token for token in tokens 
            if token.isalpha() and len(token) > 2 and token not in self.stop_words
        ]
        
        return filtered_tokens
    
    def _calculate_readability(self, text: str) -> float:
        """Calcula score de legibilidade simplificado"""
        if not text:
            return 0.0
        
        sentences = sent_tokenize(text)
        words = word_tokenize(text)
        
        if not sentences or not words:
            return 0.0
        
        # Fórmula simplificada baseada em Flesch Reading Ease
        avg_sentence_length = len(words) / len(sentences)
        avg_syllables = np.mean([self._count_syllables(word) for word in words])
        
        # Score simplificado (0-100, maior = mais fácil de ler)
        score = 206.835 - (1.015 * avg_sentence_length) - (84.6 * avg_syllables)
        return max(0, min(100, score))
    
    def _count_syllables(self, word: str) -> int:
        """Conta sílabas em uma palavra (aproximação)"""
        word = word.lower()
        vowels = 'aeiouy'
        syllable_count = 0
        previous_was_vowel = False
        
        for char in word:
            is_vowel = char in vowels
            if is_vowel and not previous_was_vowel:
                syllable_count += 1
            previous_was_vowel = is_vowel
        
        # Palavras devem ter pelo menos 1 sílaba
        return max(1, syllable_count)
    
    def _extract_word_frequency(self, lyrics_id: str, tokens: List[str], 
                               tfidf_vector, feature_names: np.ndarray) -> List[Dict]:
        """Extrai frequência de palavras e scores TF-IDF"""
        word_freq_data = []
        
        # Contar frequência local
        from collections import Counter
        word_counts = Counter(tokens)
        
        # Converter vetor TF-IDF para dicionário
        tfidf_scores = {}
        if hasattr(tfidf_vector, 'toarray'):
            tfidf_array = tfidf_vector.toarray()[0]
            for i, score in enumerate(tfidf_array):
                if score > 0:
                    tfidf_scores[feature_names[i]] = score
        
        # POS tagging para palavras mais frequentes
        top_words = [word for word, _ in word_counts.most_common(50)]
        pos_tags = dict(pos_tag(top_words)) if top_words else {}
        
        for word, frequency in word_counts.items():
            word_freq_data.append({
                'lyrics_id': lyrics_id,
                'word': word,
                'frequency': frequency,
                'tf_idf': tfidf_scores.get(word, 0.0),
                'pos_tag': pos_tags.get(word, 'UNKNOWN'),
                'is_stopword': word in self.stop_words,
                'created_at': datetime.utcnow().isoformat()
            })
        
        return word_freq_data
    
    def _analyze_sentiment(self, text: str) -> Dict:
        """Analisa sentimento do texto"""
        if not text:
            return {
                'sentiment_score': 0.0,
                'sentiment_label': 'neutral',
                'confidence': 0.0,
                'positive_words': [],
                'negative_words': [],
                'neutral_words': []
            }
        
        # Análise com VADER
        scores = self.sentiment_analyzer.polarity_scores(text)
        
        # Determinar label baseado no score composto
        compound_score = scores['compound']
        if compound_score >= 0.05:
            sentiment_label = 'positive'
        elif compound_score <= -0.05:
            sentiment_label = 'negative'
        else:
            sentiment_label = 'neutral'
        
        # Extrair palavras por sentimento (simplificado)
        tokens = word_tokenize(text.lower())
        positive_words = []
        negative_words = []
        neutral_words = []
        
        # Análise palavra por palavra (simplificada)
        for word in tokens:
            if word.isalpha() and len(word) > 2:
                word_scores = self.sentiment_analyzer.polarity_scores(word)
                if word_scores['compound'] > 0.1:
                    positive_words.append(word)
                elif word_scores['compound'] < -0.1:
                    negative_words.append(word)
                else:
                    neutral_words.append(word)
        
        return {
            'sentiment_score': compound_score,
            'sentiment_label': sentiment_label,
            'confidence': abs(compound_score),
            'positive_words': positive_words[:10],  # Limitar a 10 palavras
            'negative_words': negative_words[:10],
            'neutral_words': neutral_words[:10]
        }
    
    def load_to_bigquery(self, raw_data: List[Dict], processed_df: pd.DataFrame,
                        word_freq_df: pd.DataFrame, sentiment_df: pd.DataFrame):
        """
        Carrega dados processados no BigQuery
        
        Args:
            raw_data: Dados brutos originais
            processed_df: DataFrame com letras processadas
            word_freq_df: DataFrame com frequência de palavras
            sentiment_df: DataFrame com análise de sentimentos
        """
        logger.info("Iniciando carregamento no BigQuery")
        
        # Configuração de job
        job_config = bigquery.LoadJobConfig(
            write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
            create_disposition=bigquery.CreateDisposition.CREATE_IF_NEEDED
        )
        
        try:
            # Carregar dados brutos
            raw_df = pd.DataFrame(raw_data)
            self._load_table(raw_df, 'raw_lyrics', job_config)
            
            # Carregar dados processados
            self._load_table(processed_df, 'processed_lyrics', job_config)
            
            # Carregar frequência de palavras
            self._load_table(word_freq_df, 'word_frequency', job_config)
            
            # Carregar análise de sentimentos
            self._load_table(sentiment_df, 'sentiment_analysis', job_config)
            
            logger.info("Carregamento no BigQuery concluído com sucesso")
            
        except Exception as e:
            logger.error(f"Erro no carregamento BigQuery: {str(e)}")
            raise
    
    def _load_table(self, df: pd.DataFrame, table_name: str, job_config):
        """Carrega DataFrame em tabela específica do BigQuery"""
        if df.empty:
            logger.warning(f"DataFrame vazio para tabela {table_name}")
            return
        
        table_id = f"{self.project_id}.{self.dataset_id}.{table_name}"
        
        # Converter colunas de array para string JSON (BigQuery compatibility)
        for col in df.columns:
            if df[col].dtype == 'object':
                # Verificar se contém listas
                sample_value = df[col].dropna().iloc[0] if not df[col].dropna().empty else None
                if isinstance(sample_value, list):
                    df[col] = df[col].apply(lambda x: json.dumps(x) if isinstance(x, list) else x)
        
        job = self.bq_client.load_table_from_dataframe(df, table_id, job_config=job_config)
        job.result()  # Aguardar conclusão
        
        logger.info(f"Carregadas {len(df)} linhas na tabela {table_name}")
    
    def run_etl_pipeline(self, input_prefix: str = "raw-data/") -> Dict:
        """
        Executa pipeline ETL completo
        
        Args:
            input_prefix: Prefixo dos arquivos de entrada
            
        Returns:
            Dicionário com estatísticas da execução
        """
        start_time = datetime.utcnow()
        logger.info("Iniciando pipeline ETL completo")
        
        try:
            # 1. Extração
            raw_data = self.extract_from_storage(input_prefix)
            
            if not raw_data:
                logger.warning("Nenhum dado encontrado para processamento")
                return {'status': 'no_data', 'processed_count': 0}
            
            # 2. Transformação
            processed_df, word_freq_df, sentiment_df = self.transform_lyrics(raw_data)
            
            # 3. Carregamento
            self.load_to_bigquery(raw_data, processed_df, word_freq_df, sentiment_df)
            
            # Estatísticas finais
            end_time = datetime.utcnow()
            duration = (end_time - start_time).total_seconds()
            
            stats = {
                'status': 'success',
                'processed_count': len(raw_data),
                'duration_seconds': duration,
                'start_time': start_time.isoformat(),
                'end_time': end_time.isoformat(),
                'tables_updated': ['raw_lyrics', 'processed_lyrics', 'word_frequency', 'sentiment_analysis']
            }
            
            logger.info(f"Pipeline ETL concluído: {stats}")
            return stats
            
        except Exception as e:
            logger.error(f"Erro no pipeline ETL: {str(e)}")
            return {
                'status': 'error',
                'error_message': str(e),
                'processed_count': 0
            }


def main():
    """Função principal para execução do pipeline"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Pipeline ETL para Análise de Letras de Música')
    parser.add_argument('--project-id', required=True, help='ID do projeto GCP')
    parser.add_argument('--dataset-id', required=True, help='ID do dataset BigQuery')
    parser.add_argument('--bucket-name', required=True, help='Nome do bucket Cloud Storage')
    parser.add_argument('--input-prefix', default='raw-data/', help='Prefixo dos arquivos de entrada')
    
    args = parser.parse_args()
    
    # Inicializar e executar pipeline
    processor = LyricsETLProcessor(
        project_id=args.project_id,
        dataset_id=args.dataset_id,
        bucket_name=args.bucket_name
    )
    
    result = processor.run_etl_pipeline(args.input_prefix)
    
    print(f"Pipeline executado: {result}")
    
    # Exit code baseado no status
    exit_code = 0 if result['status'] == 'success' else 1
    exit(exit_code)


if __name__ == "__main__":
    main()

