#!/bin/bash

# Configurações
DOCKER_USERNAME="joaochorao"
NETWORK_NAME="vocalscript-net"
VOLUME_NAME="vocalscript-data"

# Criar rede e volume, se ainda não existirem
docker network inspect $NETWORK_NAME >/dev/null 2>&1 || docker network create $NETWORK_NAME
docker volume inspect $VOLUME_NAME >/dev/null 2>&1 || docker volume create $VOLUME_NAME

docker login --username $DOCKER_USERNAME

docker build -t joaochorao/vocalscript-function:latest .
docker push joaochorao/vocalscript-function:latest

docker build -t joaochorao/vocalscript-app:latest .
docker push joaochorao/vocalscript-app:latest

# Baixar imagens base (sem modificação)
docker pull mongo:latest
docker pull minio/minio

# Criar containers com imagens personalizadas
docker run -d \
  --name vocalscript-app \
  --network $NETWORK_NAME \
  -p 5001:5000 \
  -e COSMOS_DB_CONNECTION_STRING="mongodb://cosmosdb-emulator:27017" \
  -e AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=http;AccountName=azureuser;AccountKey=AzureStoragePassword123;BlobEndpoint=http://minio-storage:9000;EndpointSuffix=local" \
  $DOCKER_USERNAME/vocalscript-app:latest

docker run -d \
  --name vocalscript-function \
  --network $NETWORK_NAME \
  -p 7071:7071 \
  -e AzureWebJobsStorage="DefaultEndpointsProtocol=http;AccountName=azureuser;AccountKey=AzureStoragePassword123;BlobEndpoint=http://minio-storage:9000;EndpointSuffix=local" \
  $DOCKER_USERNAME/vocalscript-function:latest

echo "Containers criados usando suas imagens do Docker Hub!"