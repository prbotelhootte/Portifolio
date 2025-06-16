"""
Gerador de Visualizações para Análise de Letras de Música
Script Python para criar gráficos e visualizações dos dados processados
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import plotly.figure_factory as ff
from wordcloud import WordCloud
from google.cloud import bigquery
import json
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

# Configuração de estilo
plt.style.use('seaborn-v0_8')
sns.set_palette("husl")

class LyricsVisualizationGenerator:
    """
    Classe para gerar visualizações dos dados de análise de letras
    """
    
    def __init__(self, project_id: str, dataset_id: str):
        """
        Inicializa o gerador de visualizações
        
        Args:
            project_id: ID do projeto GCP
            dataset_id: ID do dataset BigQuery
        """
        self.project_id = project_id
        self.dataset_id = dataset_id
        self.client = bigquery.Client(project=project_id)
        
        # Configurações de cores
        self.colors = {
            'positive': '#4CAF50',
            'negative': '#F44336', 
            'neutral': '#9E9E9E',
            'primary': '#1976D2',
            'secondary': '#42A5F5',
            'accent': '#FF9800'
        }
        
        # Configurações de plotly
        self.plotly_config = {
            'displayModeBar': True,
            'displaylogo': False,
            'modeBarButtonsToRemove': ['pan2d', 'lasso2d']
        }
    
    def query_data(self, query: str) -> pd.DataFrame:
        """
        Executa query no BigQuery e retorna DataFrame
        
        Args:
            query: Query SQL para executar
            
        Returns:
            DataFrame com os resultados
        """
        try:
            df = self.client.query(query).to_dataframe()
            return df
        except Exception as e:
            print(f"Erro ao executar query: {str(e)}")
            return pd.DataFrame()
    
    def create_sentiment_evolution_chart(self, save_path: str = None) -> go.Figure:
        """
        Cria gráfico de evolução do sentimento ao longo do tempo
        """
        query = f"""
        SELECT 
          year,
          AVG(sentiment_score) as avg_sentiment,
          COUNT(*) as song_count,
          COUNTIF(sentiment_label = 'positive') / COUNT(*) * 100 as positive_pct,
          COUNTIF(sentiment_label = 'negative') / COUNT(*) * 100 as negative_pct
        FROM `{self.project_id}.{self.dataset_id}.raw_lyrics` r
        JOIN `{self.project_id}.{self.dataset_id}.sentiment_analysis` s ON r.id = s.lyrics_id
        WHERE year IS NOT NULL AND year BETWEEN 1980 AND 2024
        GROUP BY year
        HAVING song_count >= 5
        ORDER BY year
        """
        
        df = self.query_data(query)
        
        if df.empty:
            print("Nenhum dado encontrado para evolução de sentimento")
            return go.Figure()
        
        # Criar subplot com eixos secundários
        fig = make_subplots(
            rows=2, cols=1,
            subplot_titles=('Sentimento Médio ao Longo do Tempo', 'Distribuição de Sentimentos (%)'),
            vertical_spacing=0.1,
            specs=[[{"secondary_y": True}], [{"secondary_y": False}]]
        )
        
        # Gráfico 1: Sentimento médio
        fig.add_trace(
            go.Scatter(
                x=df['year'],
                y=df['avg_sentiment'],
                mode='lines+markers',
                name='Sentimento Médio',
                line=dict(color=self.colors['primary'], width=3),
                marker=dict(size=6)
            ),
            row=1, col=1
        )
        
        # Gráfico 2: Distribuição percentual
        fig.add_trace(
            go.Scatter(
                x=df['year'],
                y=df['positive_pct'],
                mode='lines',
                name='% Positivo',
                line=dict(color=self.colors['positive'], width=2),
                fill='tonexty'
            ),
            row=2, col=1
        )
        
        fig.add_trace(
            go.Scatter(
                x=df['year'],
                y=df['negative_pct'],
                mode='lines',
                name='% Negativo',
                line=dict(color=self.colors['negative'], width=2),
                fill='tozeroy'
            ),
            row=2, col=1
        )
        
        # Configurar layout
        fig.update_layout(
            title='Evolução do Sentimento nas Letras de Música',
            height=800,
            showlegend=True,
            template='plotly_white'
        )
        
        fig.update_xaxes(title_text="Ano", row=2, col=1)
        fig.update_yaxes(title_text="Score de Sentimento", row=1, col=1)
        fig.update_yaxes(title_text="Percentual (%)", row=2, col=1)
        
        if save_path:
            fig.write_html(save_path)
            
        return fig
    
    def create_genre_sentiment_comparison(self, save_path: str = None) -> go.Figure:
        """
        Cria gráfico de comparação de sentimentos por gênero
        """
        query = f"""
        SELECT 
          genre,
          COUNT(*) as song_count,
          AVG(sentiment_score) as avg_sentiment,
          STDDEV(sentiment_score) as sentiment_stddev,
          COUNTIF(sentiment_label = 'positive') / COUNT(*) * 100 as positive_pct
        FROM `{self.project_id}.{self.dataset_id}.raw_lyrics` r
        JOIN `{self.project_id}.{self.dataset_id}.sentiment_analysis` s ON r.id = s.lyrics_id
        WHERE genre != 'Unknown' AND genre IS NOT NULL
        GROUP BY genre
        HAVING song_count >= 20
        ORDER BY avg_sentiment DESC
        """
        
        df = self.query_data(query)
        
        if df.empty:
            print("Nenhum dado encontrado para comparação por gênero")
            return go.Figure()
        
        # Criar gráfico de barras com erro
        fig = go.Figure()
        
        fig.add_trace(
            go.Bar(
                x=df['genre'],
                y=df['avg_sentiment'],
                error_y=dict(
                    type='data',
                    array=df['sentiment_stddev'],
                    visible=True
                ),
                marker_color=df['positive_pct'],
                marker_colorscale='RdYlGn',
                marker_colorbar=dict(title="% Positivo"),
                text=df['song_count'],
                texttemplate='%{text} músicas',
                textposition='outside',
                name='Sentimento Médio'
            )
        )
        
        fig.update_layout(
            title='Sentimento Médio por Gênero Musical',
            xaxis_title='Gênero',
            yaxis_title='Score de Sentimento',
            template='plotly_white',
            height=600
        )
        
        # Adicionar linha de referência no zero
        fig.add_hline(y=0, line_dash="dash", line_color="gray", 
                     annotation_text="Neutro")
        
        if save_path:
            fig.write_html(save_path)
            
        return fig
    
    def create_wordcloud_visualization(self, sentiment_filter: str = None, 
                                     save_path: str = None) -> WordCloud:
        """
        Cria nuvem de palavras
        
        Args:
            sentiment_filter: 'positive', 'negative', 'neutral' ou None para todos
            save_path: Caminho para salvar a imagem
        """
        # Query base
        base_query = f"""
        SELECT 
          w.word,
          SUM(w.frequency) as total_frequency
        FROM `{self.project_id}.{self.dataset_id}.word_frequency` w
        """
        
        # Adicionar filtro de sentimento se especificado
        if sentiment_filter:
            base_query += f"""
            JOIN `{self.project_id}.{self.dataset_id}.sentiment_analysis` s 
              ON w.lyrics_id = s.lyrics_id
            WHERE s.sentiment_label = '{sentiment_filter}'
              AND w.is_stopword = FALSE 
              AND LENGTH(w.word) >= 3
            """
        else:
            base_query += """
            WHERE w.is_stopword = FALSE 
              AND LENGTH(w.word) >= 3
            """
        
        base_query += """
        GROUP BY w.word
        HAVING total_frequency >= 10
        ORDER BY total_frequency DESC
        LIMIT 200
        """
        
        df = self.query_data(base_query)
        
        if df.empty:
            print("Nenhum dado encontrado para nuvem de palavras")
            return None
        
        # Criar dicionário de frequências
        word_freq = dict(zip(df['word'], df['total_frequency']))
        
        # Configurar WordCloud
        wordcloud = WordCloud(
            width=1200,
            height=800,
            background_color='white',
            max_words=100,
            colormap='viridis',
            relative_scaling=0.5,
            random_state=42
        ).generate_from_frequencies(word_freq)
        
        # Plotar
        plt.figure(figsize=(15, 10))
        plt.imshow(wordcloud, interpolation='bilinear')
        plt.axis('off')
        
        title = f"Palavras Mais Frequentes"
        if sentiment_filter:
            title += f" - Sentimento {sentiment_filter.title()}"
        plt.title(title, fontsize=20, fontweight='bold', pad=20)
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
        
        plt.show()
        return wordcloud
    
    def create_artist_analysis_dashboard(self, artist_name: str, 
                                       save_path: str = None) -> go.Figure:
        """
        Cria dashboard de análise para um artista específico
        """
        # Query para dados do artista
        query = f"""
        WITH artist_data AS (
          SELECT 
            r.year,
            r.title,
            p.word_count,
            p.readability_score,
            s.sentiment_score,
            s.sentiment_label
          FROM `{self.project_id}.{self.dataset_id}.raw_lyrics` r
          JOIN `{self.project_id}.{self.dataset_id}.processed_lyrics` p ON r.id = p.id
          JOIN `{self.project_id}.{self.dataset_id}.sentiment_analysis` s ON r.id = s.lyrics_id
          WHERE LOWER(r.artist) = LOWER('{artist_name}')
            AND r.year IS NOT NULL
        ),
        artist_words AS (
          SELECT 
            w.word,
            SUM(w.frequency) as frequency,
            AVG(w.tf_idf) as avg_tfidf
          FROM `{self.project_id}.{self.dataset_id}.word_frequency` w
          JOIN `{self.project_id}.{self.dataset_id}.raw_lyrics` r ON w.lyrics_id = r.id
          WHERE LOWER(r.artist) = LOWER('{artist_name}')
            AND w.is_stopword = FALSE
            AND LENGTH(w.word) >= 3
          GROUP BY w.word
          ORDER BY frequency DESC
          LIMIT 20
        )
        SELECT * FROM artist_data
        """
        
        df = self.query_data(query)
        
        if df.empty:
            print(f"Nenhum dado encontrado para o artista: {artist_name}")
            return go.Figure()
        
        # Criar subplots
        fig = make_subplots(
            rows=2, cols=2,
            subplot_titles=(
                f'Evolução do Sentimento - {artist_name}',
                'Distribuição de Sentimentos',
                'Contagem de Palavras vs Legibilidade',
                'Evolução da Complexidade'
            ),
            specs=[[{"secondary_y": False}, {"type": "pie"}],
                   [{"secondary_y": False}, {"secondary_y": True}]]
        )
        
        # Gráfico 1: Evolução do sentimento
        yearly_sentiment = df.groupby('year')['sentiment_score'].mean().reset_index()
        fig.add_trace(
            go.Scatter(
                x=yearly_sentiment['year'],
                y=yearly_sentiment['sentiment_score'],
                mode='lines+markers',
                name='Sentimento',
                line=dict(color=self.colors['primary'])
            ),
            row=1, col=1
        )
        
        # Gráfico 2: Distribuição de sentimentos
        sentiment_counts = df['sentiment_label'].value_counts()
        fig.add_trace(
            go.Pie(
                labels=sentiment_counts.index,
                values=sentiment_counts.values,
                name="Sentimentos",
                marker_colors=[self.colors.get(label, '#999999') 
                             for label in sentiment_counts.index]
            ),
            row=1, col=2
        )
        
        # Gráfico 3: Scatter plot
        fig.add_trace(
            go.Scatter(
                x=df['word_count'],
                y=df['readability_score'],
                mode='markers',
                marker=dict(
                    color=df['sentiment_score'],
                    colorscale='RdYlGn',
                    size=8,
                    colorbar=dict(title="Sentimento")
                ),
                text=df['title'],
                name='Músicas'
            ),
            row=2, col=1
        )
        
        # Gráfico 4: Evolução da complexidade
        yearly_complexity = df.groupby('year').agg({
            'word_count': 'mean',
            'readability_score': 'mean'
        }).reset_index()
        
        fig.add_trace(
            go.Scatter(
                x=yearly_complexity['year'],
                y=yearly_complexity['word_count'],
                mode='lines',
                name='Palavras/Música',
                line=dict(color=self.colors['accent'])
            ),
            row=2, col=2
        )
        
        # Configurar layout
        fig.update_layout(
            title=f'Análise Completa - {artist_name}',
            height=800,
            showlegend=True,
            template='plotly_white'
        )
        
        if save_path:
            fig.write_html(save_path)
            
        return fig
    
    def create_complexity_heatmap(self, save_path: str = None) -> go.Figure:
        """
        Cria heatmap de complexidade por gênero e década
        """
        query = f"""
        SELECT 
          r.genre,
          FLOOR(r.year / 10) * 10 as decade,
          AVG(p.readability_score) as avg_readability,
          COUNT(*) as song_count
        FROM `{self.project_id}.{self.dataset_id}.raw_lyrics` r
        JOIN `{self.project_id}.{self.dataset_id}.processed_lyrics` p ON r.id = p.id
        WHERE r.year IS NOT NULL 
          AND r.year BETWEEN 1970 AND 2020
          AND r.genre != 'Unknown'
          AND r.genre IS NOT NULL
        GROUP BY r.genre, decade
        HAVING song_count >= 5
        ORDER BY r.genre, decade
        """
        
        df = self.query_data(query)
        
        if df.empty:
            print("Nenhum dado encontrado para heatmap de complexidade")
            return go.Figure()
        
        # Criar pivot table
        pivot_df = df.pivot(index='genre', columns='decade', values='avg_readability')
        
        # Criar heatmap
        fig = go.Figure(data=go.Heatmap(
            z=pivot_df.values,
            x=pivot_df.columns,
            y=pivot_df.index,
            colorscale='RdYlBu',
            colorbar=dict(title="Score de Legibilidade"),
            text=np.round(pivot_df.values, 1),
            texttemplate="%{text}",
            textfont={"size": 10}
        ))
        
        fig.update_layout(
            title='Legibilidade por Gênero e Década',
            xaxis_title='Década',
            yaxis_title='Gênero Musical',
            template='plotly_white',
            height=600
        )
        
        if save_path:
            fig.write_html(save_path)
            
        return fig
    
    def create_word_trend_analysis(self, words: list, save_path: str = None) -> go.Figure:
        """
        Analisa tendência de palavras específicas ao longo do tempo
        
        Args:
            words: Lista de palavras para analisar
            save_path: Caminho para salvar o gráfico
        """
        if not words:
            print("Lista de palavras não pode estar vazia")
            return go.Figure()
        
        fig = go.Figure()
        
        for word in words:
            query = f"""
            SELECT 
              r.year,
              SUM(w.frequency) as total_frequency,
              COUNT(DISTINCT w.lyrics_id) as song_count
            FROM `{self.project_id}.{self.dataset_id}.word_frequency` w
            JOIN `{self.project_id}.{self.dataset_id}.raw_lyrics` r ON w.lyrics_id = r.id
            WHERE LOWER(w.word) = LOWER('{word}')
              AND r.year IS NOT NULL
              AND r.year BETWEEN 1980 AND 2024
            GROUP BY r.year
            HAVING song_count >= 2
            ORDER BY r.year
            """
            
            df = self.query_data(query)
            
            if not df.empty:
                fig.add_trace(
                    go.Scatter(
                        x=df['year'],
                        y=df['total_frequency'],
                        mode='lines+markers',
                        name=word.title(),
                        line=dict(width=2),
                        marker=dict(size=6)
                    )
                )
        
        fig.update_layout(
            title='Tendência de Palavras ao Longo do Tempo',
            xaxis_title='Ano',
            yaxis_title='Frequência Total',
            template='plotly_white',
            height=500,
            hovermode='x unified'
        )
        
        if save_path:
            fig.write_html(save_path)
            
        return fig
    
    def generate_summary_report(self, output_dir: str = "./visualizations/"):
        """
        Gera relatório completo com todas as visualizações
        
        Args:
            output_dir: Diretório para salvar as visualizações
        """
        import os
        os.makedirs(output_dir, exist_ok=True)
        
        print("🎨 Gerando visualizações...")
        
        # 1. Evolução do sentimento
        print("📈 Criando gráfico de evolução do sentimento...")
        sentiment_fig = self.create_sentiment_evolution_chart(
            save_path=f"{output_dir}/sentiment_evolution.html"
        )
        
        # 2. Comparação por gênero
        print("🎵 Criando comparação por gênero...")
        genre_fig = self.create_genre_sentiment_comparison(
            save_path=f"{output_dir}/genre_comparison.html"
        )
        
        # 3. Nuvens de palavras
        print("☁️ Criando nuvens de palavras...")
        self.create_wordcloud_visualization(
            save_path=f"{output_dir}/wordcloud_all.png"
        )
        self.create_wordcloud_visualization(
            sentiment_filter='positive',
            save_path=f"{output_dir}/wordcloud_positive.png"
        )
        self.create_wordcloud_visualization(
            sentiment_filter='negative',
            save_path=f"{output_dir}/wordcloud_negative.png"
        )
        
        # 4. Heatmap de complexidade
        print("🔥 Criando heatmap de complexidade...")
        complexity_fig = self.create_complexity_heatmap(
            save_path=f"{output_dir}/complexity_heatmap.html"
        )
        
        # 5. Análise de tendências de palavras
        print("📊 Criando análise de tendências...")
        trend_words = ['love', 'heart', 'time', 'life', 'world']
        trend_fig = self.create_word_trend_analysis(
            words=trend_words,
            save_path=f"{output_dir}/word_trends.html"
        )
        
        # Criar índice HTML
        self.create_html_index(output_dir)
        
        print(f"✅ Relatório completo gerado em: {output_dir}")
        print(f"📄 Abra o arquivo {output_dir}/index.html para ver todas as visualizações")
    
    def create_html_index(self, output_dir: str):
        """
        Cria página HTML índice com todas as visualizações
        """
        html_content = f"""
        <!DOCTYPE html>
        <html lang="pt-BR">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Análise de Letras de Música - Dashboard</title>
            <style>
                body {{
                    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                    margin: 0;
                    padding: 20px;
                    background-color: #f5f5f5;
                }}
                .container {{
                    max-width: 1200px;
                    margin: 0 auto;
                    background-color: white;
                    padding: 30px;
                    border-radius: 10px;
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                }}
                h1 {{
                    color: #1976D2;
                    text-align: center;
                    margin-bottom: 30px;
                }}
                .grid {{
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                    gap: 20px;
                    margin-top: 30px;
                }}
                .card {{
                    background: white;
                    border: 1px solid #ddd;
                    border-radius: 8px;
                    padding: 20px;
                    text-align: center;
                    transition: transform 0.2s;
                }}
                .card:hover {{
                    transform: translateY(-2px);
                    box-shadow: 0 4px 15px rgba(0,0,0,0.1);
                }}
                .card h3 {{
                    color: #333;
                    margin-bottom: 15px;
                }}
                .card img {{
                    max-width: 100%;
                    height: auto;
                    border-radius: 5px;
                }}
                .btn {{
                    display: inline-block;
                    padding: 10px 20px;
                    background-color: #1976D2;
                    color: white;
                    text-decoration: none;
                    border-radius: 5px;
                    margin-top: 10px;
                    transition: background-color 0.2s;
                }}
                .btn:hover {{
                    background-color: #1565C0;
                }}
                .timestamp {{
                    text-align: center;
                    color: #666;
                    margin-top: 30px;
                    font-style: italic;
                }}
            </style>
        </head>
        <body>
            <div class="container">
                <h1>📊 Dashboard de Análise de Letras de Música</h1>
                <p style="text-align: center; color: #666; font-size: 18px;">
                    Visualizações interativas dos dados processados pelo pipeline ETL
                </p>
                
                <div class="grid">
                    <div class="card">
                        <h3>📈 Evolução do Sentimento</h3>
                        <p>Análise temporal dos sentimentos nas letras de música</p>
                        <a href="sentiment_evolution.html" class="btn">Ver Gráfico</a>
                    </div>
                    
                    <div class="card">
                        <h3>🎵 Comparação por Gênero</h3>
                        <p>Sentimentos médios por gênero musical</p>
                        <a href="genre_comparison.html" class="btn">Ver Gráfico</a>
                    </div>
                    
                    <div class="card">
                        <h3>☁️ Nuvem de Palavras - Geral</h3>
                        <img src="wordcloud_all.png" alt="Nuvem de Palavras Geral">
                    </div>
                    
                    <div class="card">
                        <h3>😊 Palavras Positivas</h3>
                        <img src="wordcloud_positive.png" alt="Palavras Positivas">
                    </div>
                    
                    <div class="card">
                        <h3>😔 Palavras Negativas</h3>
                        <img src="wordcloud_negative.png" alt="Palavras Negativas">
                    </div>
                    
                    <div class="card">
                        <h3>🔥 Complexidade por Gênero/Década</h3>
                        <p>Heatmap de legibilidade ao longo do tempo</p>
                        <a href="complexity_heatmap.html" class="btn">Ver Heatmap</a>
                    </div>
                    
                    <div class="card">
                        <h3>📊 Tendências de Palavras</h3>
                        <p>Evolução de palavras específicas ao longo do tempo</p>
                        <a href="word_trends.html" class="btn">Ver Tendências</a>
                    </div>
                </div>
                
                <div class="timestamp">
                    Relatório gerado em: {datetime.now().strftime('%d/%m/%Y às %H:%M:%S')}
                </div>
            </div>
        </body>
        </html>
        """
        
        with open(f"{output_dir}/index.html", "w", encoding="utf-8") as f:
            f.write(html_content)


def main():
    """
    Função principal para gerar visualizações
    """
    import argparse
    
    parser = argparse.ArgumentParser(description='Gerador de Visualizações - Análise de Letras')
    parser.add_argument('--project-id', required=True, help='ID do projeto GCP')
    parser.add_argument('--dataset-id', default='lyrics_analysis', help='ID do dataset BigQuery')
    parser.add_argument('--output-dir', default='./visualizations/', help='Diretório de saída')
    parser.add_argument('--artist', help='Nome do artista para análise específica')
    
    args = parser.parse_args()
    
    # Inicializar gerador
    generator = LyricsVisualizationGenerator(args.project_id, args.dataset_id)
    
    if args.artist:
        # Análise específica de artista
        print(f"🎤 Gerando análise para o artista: {args.artist}")
        fig = generator.create_artist_analysis_dashboard(
            artist_name=args.artist,
            save_path=f"{args.output_dir}/artist_{args.artist.replace(' ', '_').lower()}.html"
        )
    else:
        # Relatório completo
        generator.generate_summary_report(args.output_dir)


if __name__ == "__main__":
    main()

