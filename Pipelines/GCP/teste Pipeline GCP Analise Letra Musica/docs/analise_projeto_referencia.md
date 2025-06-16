# Análise do Projeto de Referência - Letras de Música

## Estrutura do Projeto Original

### Localização
- Repositório: https://github.com/theclanks/machine_learning
- Notebook: lyrics/app/lyrics/Modelo/Análise e Modelagem.ipynb
- Tamanho: 1431 linhas (1.07 MB)

### Bibliotecas Utilizadas

#### Processamento de Dados
- numpy, pandas - manipulação de dados
- json - processamento de arquivos JSON

#### Processamento de Texto (NLP)
- nltk - Natural Language Toolkit
  - FreqDist - distribuição de frequência
  - stopwords - palavras irrelevantes
  - word_tokenize, sent_tokenize - tokenização
- wordcloud - geração de nuvens de palavras
- string - manipulação de strings

#### Machine Learning
- sklearn (scikit-learn)
  - feature_extraction.text - extração de características de texto
  - model_selection - divisão de dados
  - linear_model - modelos lineares
  - svm - Support Vector Machines
  - metrics - métricas de avaliação
  - utils - utilitários

#### Visualização
- matplotlib.pyplot - gráficos básicos
- seaborn - visualizações estatísticas

#### Análise de Grafos
- networkx - análise de redes/grafos

#### Otimização
- scipy - funções científicas
- sklearn.utils - utilitários de machine learning

### Estrutura de Dados Identificada

Com base nas importações e estrutura do projeto, o pipeline trabalha com:

1. **Dados de Entrada**: Letras de música em formato texto/JSON
2. **Processamento NLP**: 
   - Tokenização de palavras e sentenças
   - Remoção de stopwords
   - Análise de frequência de palavras
3. **Análise de Sentimentos**: Usando modelos de ML
4. **Visualizações**:
   - Nuvens de palavras
   - Gráficos de distribuição
   - Análises de rede/grafos

### Funcionalidades Principais

1. **Extração e Limpeza de Texto**
2. **Análise de Frequência de Palavras**
3. **Modelagem de Machine Learning**
4. **Geração de Visualizações**
5. **Análise de Redes Semânticas**

## Requisitos para o Pipeline GCP

### Dados de Entrada
- Arquivos de texto com letras de música
- Formato: TXT, JSON ou CSV
- Armazenamento: Cloud Storage bucket

### Processamento ETL
- Limpeza e tokenização de texto
- Extração de características
- Cálculo de métricas e estatísticas
- Análise de sentimentos

### Dados de Saída (BigQuery)
- Tabela de letras processadas
- Tabela de estatísticas por música
- Tabela de palavras mais frequentes
- Tabela de análise de sentimentos

### Visualizações
- Dashboard com métricas principais
- Nuvens de palavras interativas
- Gráficos de tendências
- Análises comparativas

