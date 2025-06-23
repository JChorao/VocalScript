# Dockerfile
FROM python:3.10-slim

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y ffmpeg

# Instalar as dependências Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar o código
COPY . /app
WORKDIR /app

# Expor porta (caso uses streamlit diretamente)
EXPOSE 80

# Comando de arranque
CMD ["streamlit", "run", "app.py", "--server.port=80", "--server.enableCORS=false", "--server.enableXsrfProtection=false"]
