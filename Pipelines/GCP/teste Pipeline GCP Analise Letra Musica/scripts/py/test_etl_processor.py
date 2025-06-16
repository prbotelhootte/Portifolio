"""
Testes unitários para o pipeline ETL
"""

import unittest
from unittest.mock import Mock, patch, MagicMock
import pandas as pd
import json
from datetime import datetime
import sys
import os

# Adicionar src ao path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from etl_processor import LyricsETLProcessor

class TestLyricsETLProcessor(unittest.TestCase):
    """Testes para a classe LyricsETLProcessor"""
    
    def setUp(self):
        """Configuração inicial para os testes"""
        self.project_id = "test-project"
        self.dataset_id = "test_dataset"
        self.bucket_name = "test-bucket"
        
        # Mock dos clientes GCP
        with patch('etl_processor.storage.Client'), \
             patch('etl_processor.bigquery.Client'), \
             patch('etl_processor.cloud_logging.Client'):
            self.processor = LyricsETLProcessor(
                self.project_id, 
                self.dataset_id, 
                self.bucket_name
            )
    
    def test_normalize_lyrics_data(self):
        """Testa normalização de dados de letras"""
        # Dados de entrada
        input_data = {
            'title': 'Test Song',
            'artist': 'Test Artist',
            'lyrics': 'This is a test song'
        }
        filename = 'test.json'
        
        # Executar normalização
        result = self.processor._normalize_lyrics_data(input_data, filename)
        
        # Verificações
        self.assertEqual(result['title'], 'Test Song')
        self.assertEqual(result['artist'], 'Test Artist')
        self.assertEqual(result['lyrics'], 'This is a test song')
        self.assertEqual(result['source'], filename)
        self.assertIsNotNone(result['id'])
        self.assertIsNotNone(result['created_at'])
    
    def test_clean_text(self):
        """Testa limpeza de texto"""
        # Texto com caracteres especiais
        dirty_text = "Hello, World! This is a test... 123 #hashtag @mention"
        
        # Limpar texto
        clean_text = self.processor._clean_text(dirty_text)
        
        # Verificações
        self.assertEqual(clean_text, "hello world this is a test 123 hashtag mention")
        self.assertNotIn(',', clean_text)
        self.assertNotIn('!', clean_text)
        self.assertNotIn('#', clean_text)
    
    def test_tokenize_text(self):
        """Testa tokenização de texto"""
        text = "hello world this is a test"
        
        # Tokenizar
        tokens = self.processor._tokenize_text(text)
        
        # Verificações
        self.assertIsInstance(tokens, list)
        self.assertIn('hello', tokens)
        self.assertIn('world', tokens)
        self.assertIn('test', tokens)
        # Stopwords devem ser removidas
        self.assertNotIn('is', tokens)
        self.assertNotIn('a', tokens)
    
    def test_parse_year(self):
        """Testa parsing de anos"""
        # Testes com diferentes formatos
        self.assertEqual(self.processor._parse_year("2020"), 2020)
        self.assertEqual(self.processor._parse_year("2020-01-01"), 2020)
        self.assertEqual(self.processor._parse_year(2020), 2020)
        self.assertIsNone(self.processor._parse_year("invalid"))
        self.assertIsNone(self.processor._parse_year(None))
    
    def test_count_syllables(self):
        """Testa contagem de sílabas"""
        # Palavras de teste
        self.assertEqual(self.processor._count_syllables("hello"), 2)
        self.assertEqual(self.processor._count_syllables("world"), 1)
        self.assertEqual(self.processor._count_syllables("beautiful"), 3)
        self.assertEqual(self.processor._count_syllables("a"), 1)  # Mínimo 1
    
    def test_calculate_readability(self):
        """Testa cálculo de legibilidade"""
        # Texto simples
        simple_text = "This is a simple test. It has short sentences."
        score = self.processor._calculate_readability(simple_text)
        
        # Verificações
        self.assertIsInstance(score, float)
        self.assertGreaterEqual(score, 0)
        self.assertLessEqual(score, 100)
    
    def test_analyze_sentiment(self):
        """Testa análise de sentimentos"""
        # Texto positivo
        positive_text = "I love this amazing beautiful song"
        sentiment = self.processor._analyze_sentiment(positive_text)
        
        # Verificações
        self.assertIn('sentiment_score', sentiment)
        self.assertIn('sentiment_label', sentiment)
        self.assertIn('confidence', sentiment)
        self.assertIn('positive_words', sentiment)
        self.assertIn('negative_words', sentiment)
        self.assertIn('neutral_words', sentiment)
        
        # Score deve estar entre -1 e 1
        self.assertGreaterEqual(sentiment['sentiment_score'], -1)
        self.assertLessEqual(sentiment['sentiment_score'], 1)
    
    def test_parse_json_content(self):
        """Testa parsing de conteúdo JSON"""
        # JSON com uma música
        json_content = json.dumps({
            "title": "Test Song",
            "artist": "Test Artist",
            "lyrics": "Test lyrics"
        })
        
        result = self.processor._parse_json_content(json_content, "test.json")
        
        # Verificações
        self.assertIsInstance(result, list)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]['title'], "Test Song")
        
        # JSON com múltiplas músicas
        json_array = json.dumps([
            {"title": "Song 1", "artist": "Artist 1", "lyrics": "Lyrics 1"},
            {"title": "Song 2", "artist": "Artist 2", "lyrics": "Lyrics 2"}
        ])
        
        result = self.processor._parse_json_content(json_array, "test.json")
        
        # Verificações
        self.assertEqual(len(result), 2)
        self.assertEqual(result[0]['title'], "Song 1")
        self.assertEqual(result[1]['title'], "Song 2")
    
    def test_parse_txt_content(self):
        """Testa parsing de conteúdo TXT"""
        txt_content = "Test Song Title\nThis is the first line of lyrics\nThis is the second line"
        
        result = self.processor._parse_txt_content(txt_content, "test.txt")
        
        # Verificações
        self.assertIsInstance(result, list)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]['title'], "Test Song Title")
        self.assertIn("first line", result[0]['lyrics'])
        self.assertIn("second line", result[0]['lyrics'])
    
    @patch('etl_processor.pd.read_csv')
    def test_parse_csv_content(self, mock_read_csv):
        """Testa parsing de conteúdo CSV"""
        # Mock do DataFrame
        mock_df = pd.DataFrame([
            {'title': 'Song 1', 'artist': 'Artist 1', 'lyrics': 'Lyrics 1'},
            {'title': 'Song 2', 'artist': 'Artist 2', 'lyrics': 'Lyrics 2'}
        ])
        mock_read_csv.return_value = mock_df
        
        csv_content = "title,artist,lyrics\nSong 1,Artist 1,Lyrics 1\nSong 2,Artist 2,Lyrics 2"
        
        result = self.processor._parse_csv_content(csv_content, "test.csv")
        
        # Verificações
        self.assertIsInstance(result, list)
        self.assertEqual(len(result), 2)
        self.assertEqual(result[0]['title'], "Song 1")
        self.assertEqual(result[1]['title'], "Song 2")
    
    def test_generate_id(self):
        """Testa geração de IDs únicos"""
        data1 = {'title': 'Test Song', 'artist': 'Test Artist'}
        data2 = {'title': 'Test Song', 'artist': 'Test Artist'}
        data3 = {'title': 'Different Song', 'artist': 'Test Artist'}
        
        id1 = self.processor._generate_id(data1, "file1.json")
        id2 = self.processor._generate_id(data2, "file1.json")
        id3 = self.processor._generate_id(data3, "file1.json")
        
        # IDs iguais para dados iguais
        self.assertEqual(id1, id2)
        # IDs diferentes para dados diferentes
        self.assertNotEqual(id1, id3)
        # IDs devem ser strings hexadecimais
        self.assertIsInstance(id1, str)
        self.assertEqual(len(id1), 32)  # MD5 hash length


class TestConfigValidation(unittest.TestCase):
    """Testes para validação de configuração"""
    
    def test_config_validation(self):
        """Testa validação de configurações"""
        from config.config import Config
        
        # Configuração inválida (valores padrão)
        validation = Config.validate_config()
        self.assertFalse(validation['valid'])
        self.assertIn('PROJECT_ID', validation['missing_variables'])
        
    def test_get_table_schema(self):
        """Testa obtenção de schemas de tabelas"""
        from config.config import Config
        
        # Schema existente
        schema = Config.get_table_schema('raw_lyrics')
        self.assertIsInstance(schema, list)
        self.assertGreater(len(schema), 0)
        
        # Schema inexistente
        schema = Config.get_table_schema('nonexistent_table')
        self.assertEqual(schema, [])


class TestDataTransformation(unittest.TestCase):
    """Testes para transformações de dados"""
    
    def setUp(self):
        """Configuração inicial"""
        with patch('etl_processor.storage.Client'), \
             patch('etl_processor.bigquery.Client'), \
             patch('etl_processor.cloud_logging.Client'):
            self.processor = LyricsETLProcessor("test", "test", "test")
    
    def test_transform_lyrics_empty_data(self):
        """Testa transformação com dados vazios"""
        empty_data = []
        
        processed_df, word_freq_df, sentiment_df = self.processor.transform_lyrics(empty_data)
        
        # Verificações
        self.assertIsInstance(processed_df, pd.DataFrame)
        self.assertIsInstance(word_freq_df, pd.DataFrame)
        self.assertIsInstance(sentiment_df, pd.DataFrame)
        self.assertTrue(processed_df.empty)
        self.assertTrue(word_freq_df.empty)
        self.assertTrue(sentiment_df.empty)
    
    def test_transform_lyrics_valid_data(self):
        """Testa transformação com dados válidos"""
        test_data = [
            {
                'id': 'test1',
                'title': 'Happy Song',
                'artist': 'Test Artist',
                'lyrics': 'This is a happy beautiful wonderful song about love and joy'
            }
        ]
        
        processed_df, word_freq_df, sentiment_df = self.processor.transform_lyrics(test_data)
        
        # Verificações
        self.assertFalse(processed_df.empty)
        self.assertFalse(word_freq_df.empty)
        self.assertFalse(sentiment_df.empty)
        
        # Verificar colunas esperadas
        expected_processed_cols = ['id', 'title', 'artist', 'word_count', 'unique_words']
        for col in expected_processed_cols:
            self.assertIn(col, processed_df.columns)
        
        expected_word_freq_cols = ['lyrics_id', 'word', 'frequency', 'tf_idf']
        for col in expected_word_freq_cols:
            self.assertIn(col, word_freq_df.columns)
        
        expected_sentiment_cols = ['lyrics_id', 'sentiment_score', 'sentiment_label']
        for col in expected_sentiment_cols:
            self.assertIn(col, sentiment_df.columns)


if __name__ == '__main__':
    # Configurar logging para testes
    import logging
    logging.basicConfig(level=logging.WARNING)
    
    # Executar testes
    unittest.main(verbosity=2)

