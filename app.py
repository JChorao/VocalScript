import streamlit as st
from azure.storage.blob import BlobServiceClient
from azure.cosmos import CosmosClient
from pydub import AudioSegment
import pandas as pd
import uuid
import os
import tempfile

# === VARIÁVEIS DE AMBIENTE ===
AZURE_STORAGE_CONN = os.getenv("AZURE_STORAGE_CONNECTION_STRING")
AZURE_CONTAINER_NAME = os.getenv("AZURE_CONTAINER_NAME", "audios")

COSMOS_CONN = os.getenv("COSMOS_DB_CONN_STRING")
COSMOS_DB_NAME = os.getenv("COSMOS_DB_NAME")
COSMOS_CONTAINER_NAME = os.getenv("COSMOS_DB_CONTAINER_NAME")

# === CLIENTES AZURE ===
blob_service_client = BlobServiceClient.from_connection_string(AZURE_STORAGE_CONN)

def get_transcricoes():
    if not all([COSMOS_CONN, COSMOS_DB_NAME, COSMOS_CONTAINER_NAME]):
        st.error("❌ Erro na configuração do Cosmos DB.")
        return []

    client = CosmosClient.from_connection_string(COSMOS_CONN)
    db = client.get_database_client(COSMOS_DB_NAME)
    container = db.get_container_client(COSMOS_CONTAINER_NAME)
    items = list(container.read_all_items())
    return items

def upload_para_blob(nome_ficheiro, caminho_local):
    blob_client = blob_service_client.get_blob_client(container=AZURE_CONTAINER_NAME, blob=nome_ficheiro)
    with open(caminho_local, "rb") as f:
        blob_client.upload_blob(f, overwrite=True)
    return True

# === STREAMLIT UI ===
st.title("🎹 VocalScript - Transcrição de Áudio para Texto")

idioma_map = {
    "🇵🇹 Português (PT)": "pt-PT",
    "🇧🇷 Português (BR)": "pt-BR",
    "🇺🇸 English (US)": "en-US",
    "🇪🇸 Español (ES)": "es-ES",
    "🇫🇷 Français (FR)": "fr-FR"
}
idioma_label = st.selectbox("🌐 Seleciona o idioma do áudio", list(idioma_map.keys()))
idioma_code = idioma_map[idioma_label]

uploaded_file = st.file_uploader("📤 Faz upload de um ficheiro .mp3 ou .wav", type=["mp3", "wav"])

if uploaded_file:
    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
        temp_wav_path = tmp.name

        if uploaded_file.type == "audio/mpeg":
            audio = AudioSegment.from_file(uploaded_file, format="mp3")
            audio.export(temp_wav_path, format="wav")
            st.info("🔄 Ficheiro .mp3 convertido para .wav")
        else:
            tmp.write(uploaded_file.read())
            temp_wav_path = tmp.name

        blob_name = f"{idioma_code}__{uuid.uuid4()}.wav"

        try:
            upload_para_blob(blob_name, temp_wav_path)
            st.success(f"✅ Ficheiro '{blob_name}' carregado com sucesso!")
        except Exception as e:
            st.error(f"❌ Erro ao carregar para o Blob Storage: {e}")

st.subheader("📄 Transcrições guardadas")

transcricoes = get_transcricoes()
if transcricoes:
    df = pd.DataFrame(transcricoes)

    cols = ["filename", "transcription"]
    if "translation" in df.columns:
        cols.append("translation")
    st.dataframe(df[cols])

    csv = df.to_csv(index=False).encode("utf-8")
    st.download_button("⬇️ Exportar CSV", csv, "transcricoes.csv", "text/csv")

    for index, row in df.iterrows():
        translation = row.get("translation")
        if translation:
            st.download_button(
                label=f"⬇️ Tradução: {row.get('filename', 'sem_nome')}",
                data=translation,
                file_name=f"{row.get('filename', 'audio')}_traducao.txt",
                mime="text/plain"
            )
else:
    st.info("Ainda não há transcrições disponíveis.")
