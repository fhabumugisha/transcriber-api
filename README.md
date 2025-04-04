# Faster-Whisper Transcription API

Un microservice d'API de transcription audio basé sur Faster-Whisper, prêt à être déployé sur Google Cloud Run.

## Fonctionnalités

- ✅ API REST pour la transcription audio
- ✅ Supporte plusieurs modèles de Faster-Whisper (tiny, base, small, medium, large-v1, large-v2, large-v3)
- ✅ Options de langue configurable (auto-détection possible)
- ✅ Déploiement automatisé via GitHub Actions
- ✅ Optimisé pour Google Cloud Run

## API Endpoints

### POST /transcribe

Transcrit un fichier audio en texte.

**Request:**
```
POST /transcribe
Content-Type: multipart/form-data
- file: fichier audio (mp3, wav, m4a, etc.)
- language: fr / en / auto (optionnel)
- model: tiny / base / small / medium / large-v1 / large-v2 / large-v3 (défaut: small)
```

**Response:**
```json
{
  "model": "small",
  "language": "fr",
  "text": "Texte transcrit complet ici...",
  "segments": [
    {
      "id": 0,
      "start": 0.0,
      "end": 2.5,
      "text": "Premier segment..."
    },
    {
      "id": 1,
      "start": 2.5,
      "end": 5.0,
      "text": "Deuxième segment..."
    }
  ]
}
```

## Déploiement

### Prérequis

1. Un compte Google Cloud avec Cloud Run activé
2. Un projet GitHub pour l'intégration continue
3. Les secrets GitHub suivants configurés:
   - `GCP_PROJECT_ID`: L'ID de votre projet Google Cloud
   - `GCP_SA_KEY`: La clé JSON du compte de service Google Cloud avec les permissions nécessaires

### Déploiement local

```bash
# Cloner le repo
git clone https://github.com/user/faster-whisper-api.git
cd faster-whisper-api

# Construire l'image Docker
docker build -t faster-whisper-api .

# Exécuter le conteneur
docker run -p 8080:8080 faster-whisper-api
```

### Utilisation des GitHub Actions

Le déploiement est automatisé via GitHub Actions. Pour déployer sur Cloud Run:

1. Poussez vos modifications sur la branche principale
2. GitHub Actions construira et déploiera automatiquement l'API sur Cloud Run
3. L'URL de service sera affichée dans les journaux d'exécution des actions

## Structure du projet

```
faster-whisper-api/
├── app.py                 # Code principal de l'API FastAPI
├── requirements.txt       # Dépendances Python
├── Dockerfile             # Configuration Docker pour Cloud Run
├── README.md              # Documentation
└── .github/workflows/     # Configuration GitHub Actions
    └── deploy.yml         # Workflow de déploiement
```

## Configuration

Les paramètres configurables se trouvent dans les fichiers suivants:

- **app.py**: Configuration de l'API et paramètres Faster-Whisper
- **Dockerfile**: Configuration du conteneur et ressources
- **.github/workflows/deploy.yml**: Paramètres de déploiement Cloud Run

## Licence

MIT 