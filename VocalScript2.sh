
#-----------------------------------------------------
# Azure Deployment
#-----------------------------------------------------

# Variáveis
LOCATION="FranceCentral"
RESOURCE_GROUP="rg-vocalscript"

# az login  # Descomente se necessário

# Criar Resource Group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Storage Account
az storage account create \
    --name "vocalstoragedb" \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Standard_LRS \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false

STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
    --name "vocalstoragedb" \
    --resource-group $RESOURCE_GROUP \
    --output tsv)

az storage container create \
    --name "audios" \
    --account-name "vocalstoragedb" \
    --auth-mode login \
    --public-access off

# Container Registry
az acr create \
    --name "vocalscriptacr" \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Basic \
    --admin-enabled true

# Cosmos DB
az cosmosdb create \
    --name "vocal-cosmosdb" \
    --resource-group $RESOURCE_GROUP \
    --locations regionName=$LOCATION failoverPriority=0 isZoneRedundant=false \
    --kind GlobalDocumentDB \
    --default-consistency-level "Session" \
    --enable-free-tier false

az cosmosdb sql database create \
    --account-name "vocal-cosmosdb" \
    --name "TranscricoesDB" \
    --resource-group $RESOURCE_GROUP

az cosmosdb sql container create \
    --account-name "vocal-cosmosdb" \
    --database-name "TranscricoesDB" \
    --name "Transcricoes" \
    --resource-group $RESOURCE_GROUP \
    --partition-key-path "/id"

COSMOS_CONNECTION_STRING=$(az cosmosdb keys list \
    --name "vocal-cosmosdb" \
    --resource-group $RESOURCE_GROUP \
    --type connection-strings \
    --query "connectionStrings[0].connectionString" \
    --output tsv)

# App Service Plan
az appservice plan create \
    --name "asp-vocalscript" \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --is-linux \
    --sku B1

# Web App - Backend
az webapp create \
    --name "vocalscript-app" \
    --resource-group $RESOURCE_GROUP \
    --plan "asp-vocalscript" \
    --runtime "DOCKER|$DOCKER_USERNAME/vocalscript-app"

az webapp identity assign \
    --name "vocalscript-app" \
    --resource-group $RESOURCE_GROUP

az webapp config appsettings set \
    --name "vocalscript-app" \
    --resource-group $RESOURCE_GROUP \
    --settings \
        "COSMOS_DB_CONNECTION_STRING=$COSMOS_CONNECTION_STRING;DatabaseName=TranscricoesDB;" \
        "WEBSITES_ENABLE_APP_SERVICE_STORAGE=false" \
        "AZURE_STORAGE_CONNECTION_STRING=$STORAGE_CONNECTION_STRING" \
        "AZURE_CONTAINER_NAME=audios" \
        "COSMOS_DB_CONTAINER_NAME=Transcricoes" \
        "API_BASE_URL=https://vocalscript-app.azurewebsites.net"

# Cognitive Services
az cognitiveservices account create \
    --name "vocal-speech-to-text" \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --kind SpeechServices \
    --sku S0 \
    --yes

az cognitiveservices account create \
    --name "vocaltranslator" \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --kind TextTranslation \
    --sku S1 \
    --yes

# Function App - Storage & Insights
az storage account create \
    --name "functionstoragebd" \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Standard_LRS

az monitor app-insights component create \
    --app "vocalscript-func-ai-$RANDOM" \
    --location $LOCATION \
    --resource-group $RESOURCE_GROUP \
    --application-type web

AI_CONNECTION_STRING=$(az monitor app-insights component show \
    --app "vocalscript-func-ai-$RANDOM" \
    --resource-group $RESOURCE_GROUP \
    --query "connectionString" \
    --output tsv)

# Function App - Docker Image
az functionapp create \
    --name "vocalscript-function" \
    --resource-group $RESOURCE_GROUP \
    --storage-account "functionstoragebd" \
    --plan "asp-vocalscript" \
    --functions-version 4 \
    --os-type Linux \
    --deployment-container-image-name "$DOCKER_USERNAME/vocalscript-function:latest"

az functionapp config appsettings set \
    --name "vocalscript-function" \
    --resource-group $RESOURCE_GROUP \
    --settings \
        "FUNCTIONS_WORKER_RUNTIME=node" \
        "AzureWebJobsStorage=$STORAGE_CONNECTION_STRING" \
        "APPLICATIONINSIGHTS_CONNECTION_STRING=$AI_CONNECTION_STRING"

az functionapp identity assign \
    --name "vocalscript-function" \
    --resource-group $RESOURCE_GROUP

# Finalização
echo "Deployment completed!"
echo "Cosmos DB Connection String: $COSMOS_CONNECTION_STRING;DatabaseName=TranscricoesDB;"
echo "Storage Connection String: $STORAGE_CONNECTION_STRING"
echo "App URL: https://vocalscript-app.azurewebsites.net"
echo "Function URL: https://vocalscript-function.azurewebsites.net"
