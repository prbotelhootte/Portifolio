"""
Configurações do pipeline ETL
"""

import os
from typing import Dict, Any

class Config:
    """Classe de configuração centralizada"""
    
    # GCP Configuration
    PROJECT_ID = os.getenv('GCP_PROJECT_ID', 'your-project-id')
    DATASET_ID = os.getenv('BQ_DATASET_ID', 'lyrics_analysis')
    BUCKET_NAME = os.getenv('GCS_BUCKET_NAME', 'lyrics-data-bucket')
    
    # Cloud Run Configuration
    SERVICE_ACCOUNT_EMAIL = os.getenv('SERVICE_ACCOUNT_EMAIL', '')
    
    # Processing Configuration
    INPUT_PREFIX = os.getenv('INPUT_PREFIX', 'raw-data/')
    BATCH_SIZE = int(os.getenv('BATCH_SIZE', '100'))
    MAX_WORKERS = int(os.getenv('MAX_WORKERS', '4'))
    
    # NLP Configuration
    TFIDF_MAX_FEATURES = int(os.getenv('TFIDF_MAX_FEATURES', '5000'))
    MIN_WORD_LENGTH = int(os.getenv('MIN_WORD_LENGTH', '3'))
    
    # BigQuery Table Schemas
    SCHEMAS = {
        'raw_lyrics': [
            {'name': 'id', 'type': 'STRING', 'mode': 'REQUIRED'},
            {'name': 'title', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'artist', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'album', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'genre', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'year', 'type': 'INTEGER', 'mode': 'NULLABLE'},
            {'name': 'lyrics', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'source', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'created_at', 'type': 'TIMESTAMP', 'mode': 'NULLABLE'},
            {'name': 'file_path', 'type': 'STRING', 'mode': 'NULLABLE'}
        ],
        
        'processed_lyrics': [
            {'name': 'id', 'type': 'STRING', 'mode': 'REQUIRED'},
            {'name': 'title', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'artist', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'word_count', 'type': 'INTEGER', 'mode': 'NULLABLE'},
            {'name': 'unique_words', 'type': 'INTEGER', 'mode': 'NULLABLE'},
            {'name': 'avg_word_length', 'type': 'FLOAT', 'mode': 'NULLABLE'},
            {'name': 'readability_score', 'type': 'FLOAT', 'mode': 'NULLABLE'},
            {'name': 'language', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'processed_text', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'tokens', 'type': 'STRING', 'mode': 'NULLABLE'},  # JSON array as string
            {'name': 'processed_at', 'type': 'TIMESTAMP', 'mode': 'NULLABLE'}
        ],
        
        'word_frequency': [
            {'name': 'lyrics_id', 'type': 'STRING', 'mode': 'REQUIRED'},
            {'name': 'word', 'type': 'STRING', 'mode': 'REQUIRED'},
            {'name': 'frequency', 'type': 'INTEGER', 'mode': 'NULLABLE'},
            {'name': 'tf_idf', 'type': 'FLOAT', 'mode': 'NULLABLE'},
            {'name': 'pos_tag', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'is_stopword', 'type': 'BOOLEAN', 'mode': 'NULLABLE'},
            {'name': 'created_at', 'type': 'TIMESTAMP', 'mode': 'NULLABLE'}
        ],
        
        'sentiment_analysis': [
            {'name': 'lyrics_id', 'type': 'STRING', 'mode': 'REQUIRED'},
            {'name': 'sentiment_score', 'type': 'FLOAT', 'mode': 'NULLABLE'},
            {'name': 'sentiment_label', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'confidence', 'type': 'FLOAT', 'mode': 'NULLABLE'},
            {'name': 'positive_words', 'type': 'STRING', 'mode': 'NULLABLE'},  # JSON array
            {'name': 'negative_words', 'type': 'STRING', 'mode': 'NULLABLE'},  # JSON array
            {'name': 'neutral_words', 'type': 'STRING', 'mode': 'NULLABLE'},   # JSON array
            {'name': 'analyzed_at', 'type': 'TIMESTAMP', 'mode': 'NULLABLE'}
        ]
    }
    
    @classmethod
    def get_table_schema(cls, table_name: str) -> list:
        """Retorna schema da tabela especificada"""
        return cls.SCHEMAS.get(table_name, [])
    
    @classmethod
    def validate_config(cls) -> Dict[str, Any]:
        """Valida configurações obrigatórias"""
        required_vars = ['PROJECT_ID', 'DATASET_ID', 'BUCKET_NAME']
        missing_vars = []
        
        for var in required_vars:
            if not getattr(cls, var) or getattr(cls, var) == f'your-{var.lower().replace("_", "-")}':
                missing_vars.append(var)
        
        return {
            'valid': len(missing_vars) == 0,
            'missing_variables': missing_vars,
            'current_config': {
                'PROJECT_ID': cls.PROJECT_ID,
                'DATASET_ID': cls.DATASET_ID,
                'BUCKET_NAME': cls.BUCKET_NAME,
                'BATCH_SIZE': cls.BATCH_SIZE,
                'MAX_WORKERS': cls.MAX_WORKERS
            }
        }


# Environment-specific configurations
class DevelopmentConfig(Config):
    """Configuração para desenvolvimento"""
    DEBUG = True
    BATCH_SIZE = 10
    MAX_WORKERS = 2


class ProductionConfig(Config):
    """Configuração para produção"""
    DEBUG = False
    BATCH_SIZE = 100
    MAX_WORKERS = 4


class TestingConfig(Config):
    """Configuração para testes"""
    DEBUG = True
    BATCH_SIZE = 5
    MAX_WORKERS = 1
    DATASET_ID = 'lyrics_analysis_test'


def get_config(environment: str = None) -> Config:
    """
    Retorna configuração baseada no ambiente
    
    Args:
        environment: 'development', 'production', 'testing'
        
    Returns:
        Instância da classe de configuração apropriada
    """
    if environment is None:
        environment = os.getenv('ENVIRONMENT', 'development')
    
    config_map = {
        'development': DevelopmentConfig,
        'production': ProductionConfig,
        'testing': TestingConfig
    }
    
    return config_map.get(environment, DevelopmentConfig)()

