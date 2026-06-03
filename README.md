# 🧠 MindSnap — Ton deuxième cerveau

> Une application de gestion de connaissances personnelles augmentée par l'IA.
> Stocke tes notes, documents et liens. Retrouve-les instantanément grâce à
> l'intelligence artificielle.

---

## Table des matières

1. [Présentation](#présentation)
2. [Comment lancer le projet](#comment-lancer-le-projet)
3. [Architecture](#architecture)
4. [Comment ça marche ?](#comment-ça-marche-)
5. [Les modèles](#les-modèles)
6. [Les services](#les-services)
7. [Les jobs asynchrones](#les-jobs-asynchrones)
8. [Les APIs externes](#les-apis-externes)
9. [Les tests](#les-tests)
10. [Déploiement](#déploiement)
11. [Ressources pour apprendre](#ressources-pour-apprendre)
12. [Roadmap](#roadmap)

---

## Présentation

**MindSnap** est ton assistant personnel de connaissances. Imagine un carnet de notes
intelligent qui :

- 📂 **Organise** tes documents en dossiers
- 🔗 **Extrait** automatiquement le contenu des pages web que tu sauvegardes
- 🤖 **Comprend** le sens de tes questions grâce à l'IA
- 💬 **Te répond** en s'appuyant sur tes propres documents
- 🏷️ **Classe** automatiquement tes documents avec des tags
- 📝 **Résume** chaque document en 3 phrases
- 🎤 **Transcrit** ta voix en texte et lit les réponses à voix haute

> **Projet étudiant** — Réalisé en 2 semaines par une équipe d'étudiants.
> Stack : Ruby on Rails 8, PostgreSQL, pgvector, Hotwire, Bootstrap 5.

---

## Comment lancer le projet

### Prérequis

- **Ruby** 3.3.5 (`rbenv` recommandé)
- **PostgreSQL** 15+ avec l'extension `pgvector`
- **Clé API OpenRouter** (gratuit, [openrouter.ai/keys](https://openrouter.ai/keys))

### Installation

```bash
# 1. Cloner le projet
git clone git@github.com:G2025-mahfoudhi/mindSnap.git
cd mindSnap

# 2. Installer Ruby et les gems
rbenv install 3.3.5  # si pas déjà fait
bundle install

# 3. Installer pgvector (macOS)
brew install pgvector
# Si PostgreSQL 15 : compiler manuellement (voir section Déploiement)

# 4. Configurer les variables d'environnement
cp .env.example .env   # si le fichier existe
# Éditer .env avec ta clé OpenRouter :
#   OPENROUTER_API_KEY=sk-or-v1-...
#   OPENROUTER_MODEL=nvidia/nemotron-3-super-120b-a12b:free
#   OPENROUTER_BASE_URL=https://openrouter.ai/api/v1

# 5. Créer la base de données
bin/rails db:create db:migrate

# 6. Activer pgvector dans la base
psql -d mind_snap_development -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

### Lancer le serveur

```bash
bin/dev
```

Puis ouvre [http://localhost:3000](http://localhost:3000)

### Lancer les tests

```bash
bin/rails test                    # Tous les tests
bin/rails test test/models/       # Tests des modèles uniquement
bin/rails test test/services/     # Tests des services
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     NAVIGATEUR                           │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │  Pages ERB   │  │  Stimulus JS │  │   Bootstrap 5 │  │
│  │  (vues HTML) │  │ (interactivité)│ │   (design)   │  │
│  └──────┬───────┘  └──────┬───────┘  └───────────────┘  │
│         │                 │                               │
│         ▼                 ▼                               │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              Turbo / Hotwire                         │ │
│  │     (mise à jour temps réel sans rechargement)       │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────┬───────────────────────────────┘
                          │ HTTP
┌─────────────────────────▼───────────────────────────────┐
│                     SERVEUR RAILS                         │
│                                                            │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │ Contrôleurs  │  │   Modèles    │  │   Services     │  │
│  │              │  │              │  │                │  │
│  │ → Reçoivent  │  │ → Structure  │  │ → Logique      │  │
│  │   les requêtes│ │   des données│  │   métier       │  │
│  └──────┬───────┘  └──────┬───────┘  └───────┬────────┘  │
│         │                 │                   │            │
│  ┌──────▼─────────────────▼───────────────────▼────────┐  │
│  │                  Solid Queue                         │  │
│  │        (jobs asynchrones : embedding, IA...)         │  │
│  └────────────────────────┬─────────────────────────────┘  │
└───────────────────────────┬─────────────────────────────────┘
                            │
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                  ▼
   ┌─────────────┐   ┌─────────────┐   ┌──────────────┐
   │ PostgreSQL  │   │  OpenRouter │   │  Cloudinary   │
   │ + pgvector  │   │  (IA/LLM)  │   │  (fichiers)  │
   └─────────────┘   └─────────────┘   └──────────────┘
```

### Les couches de l'application

| Couche | Rôle | Exemple |
|--------|------|---------|
| **Vues (ERB)** | Ce que l'utilisateur voit | `app/views/conversations/show.html.erb` |
| **Stimulus (JS)** | Interactivité dans le navigateur | `voice_controller.js` (micro, audio) |
| **Contrôleurs** | Traitent les requêtes HTTP | `MessagesController#create` |
| **Modèles** | Structure des données + validations | `Document`, `Conversation` |
| **Services** | Logique métier réutilisable | `RagService` (recherche IA) |
| **Jobs** | Tâches en arrière-plan | `EmbedDocumentJob` (vectorisation) |
| **Base de données** | Stockage persistant | PostgreSQL + pgvector |

> 💡 **Pour comprendre** : C'est le pattern **MVC** (Modèle-Vue-Contrôleur) classique de Rails,
> enrichi de **Services** (logique métier) et **Jobs** (tâches asynchrones).

---

## Comment ça marche ?

### 1. Création d'un document

```
Utilisateur crée un document
         │
         ▼
┌─────────────────────────────────────────────┐
│  Document créé en base (titre, contenu...)  │
└─────────────────────────────────────────────┘
         │
         │ after_commit (automatique)
         ▼
┌─────────────────────────────────────────────┐
│  1. Si type = "Lien" + URL                   │
│     → ScrapeLinkJob scrape le contenu        │
│     → Nokogiri extrait le texte de la page   │
│                                              │
│  2. EmbedDocumentJob                         │
│     → ChunkingService découpe en fragments   │
│     → EmbeddingService génère des vecteurs   │
│     → Stockage dans pgvector (HNSW)          │
│                                              │
│  3. SummarizeDocumentJob                     │
│     → L'IA génère un résumé en 3 phrases     │
│                                              │
│  4. TagDocumentJob                           │
│     → L'IA suggère 3-5 mots-clés             │
└─────────────────────────────────────────────┘
```

### 2. Chat avec l'IA (RAG)

Le **RAG** (Retrieval Augmented Generation) est la technique qui permet à l'IA
de répondre en s'appuyant sur TES documents :

```
Tu poses une question : "C'est quoi le machine learning ?"
         │
         ▼
┌─────────────────────────────────────────────┐
│  1. EmbeddingService transforme ta question  │
│     en vecteur mathématique (1024 nombres)   │
│                                              │
│  2. RagService.search                        │
│     → Cherche les chunks les plus proches    │
│       dans pgvector (similarité cosinus)      │
│     → Trouve : "Le ML est une branche..."    │
│                                              │
│  3. RagService.format_context                │
│     → Formate les résultats :                │
│       [Document: "Intro ML"]                 │
│       Le machine learning est une branche... │
│                                              │
│  4. OpenRouterService                        │
│     → Envoie le prompt système enrichi        │
│       + contexte + ta question au LLM        │
│     → Le LLM répond en citant tes documents  │
└─────────────────────────────────────────────┘
```

> 💡 **RAG sans jargon** : Au lieu de demander à l'IA de répondre avec ses
> connaissances générales, on lui donne d'abord les passages pertinents de TES
> documents. L'IA les lit et répond en s'appuyant dessus. Comme si tu lui passais
> une fiche de révision avant l'examen.

### 3. Recherche sémantique

La recherche sémantique comprend le **sens** de ta question, pas juste les mots :

- Recherche classique : cherche "chat" → trouve les documents contenant "chat"
- Recherche sémantique : cherche "animal domestique" → trouve aussi les documents
  sur les "chats" même si le mot n'apparaît pas

Cette "compréhension" est possible grâce aux **embeddings vectoriels** : chaque
texte est transformé en une liste de 1024 nombres qui représentent son sens.
Deux textes qui parlent de la même chose auront des vecteurs proches.

---

## Les modèles

Voici les 9 modèles de l'application et leurs relations :

```
┌──────┐       ┌──────────┐       ┌─────────────┐
│ User │──1:N──│  Folder  │──1:N──│   Document   │
└──┬───┘       └────┬─────┘       └──┬────┬─────┘
   │                │                │    │
   │                │ parent/children│    │ 1:N
   │                └────────────────┘    │
   │                                     ▼
   │ 1:N                           ┌──────────────┐
   ├───────────────────────────────│ DocumentChunk │
   │                               │ (vecteur 1024)│
   │                               └──────────────┘
   │ 1:N
   ├───────────────────────────────┐
   │                               ▼
   │                        ┌──────────────┐
   │                        │ Conversation │
   │                        └──────┬───────┘
   │                               │ 1:N
   │                               ▼
   │                        ┌──────────────┐
   │                        │   Message    │
   │                        └──────────────┘
   │ 1:N
   ├───────────────────────────────┐
   │                               ▼
   │                        ┌──────────────┐     ┌──────────┐
   │                        │   Tagging    │─────│   Tag    │
   │                        │ (polymorphic)│     └──────────┘
   │                        └──────┬───────┘
   │                               │ taggable = Document
   └───────────────────────────────┘
```

| Modèle | Fichier | Responsabilité |
|--------|---------|---------------|
| **User** | `app/models/user.rb` | Compte utilisateur (Devise). Possède tout. |
| **Folder** | `app/models/folder.rb` | Dossier (arborescence parent/enfant). |
| **Document** | `app/models/document.rb` | Note, article, lien ou fichier. Le cœur de l'app. |
| **DocumentChunk** | `app/models/document_chunk.rb` | Fragment de document + vecteur pour la recherche IA. |
| **Conversation** | `app/models/conversation.rb` | Fil de discussion avec l'IA. |
| **Message** | `app/models/message.rb` | Un message (user ou assistant). |
| **Tag** | `app/models/tag.rb` | Mot-clé généré automatiquement par l'IA. |
| **Tagging** | `app/models/tagging.rb` | Lien entre un tag et un document. |

### Les colonnes importantes de `documents`

```
documents
├── title             → Titre du document
├── content           → Contenu texte (rempli automatiquement si type "Lien")
├── document_type     → "Note", "Article", "Lien", "Fichier"
├── source_url        → URL originale (pour les liens)
├── summary           → Résumé généré par l'IA (3 phrases)
├── embedding_status  → "pending" → "processing" → "completed" / "failed"
├── scraping_status   → "scraping" → "scraped" / "failed"
├── folder_id         → Dossier parent (optionnel)
└── user_id           → Propriétaire
```

---

## Les services

Les **services** contiennent la logique métier. Ils sont dans `app/services/`.

| Service | Rôle | Utilisé par |
|---------|------|-------------|
| **OpenRouterService** | Dialogue avec l'IA (historique + RAG + fallback) | `MessagesController` |
| **RagService** | Recherche vectorielle + formatage du contexte | `OpenRouterService`, `SearchesController` |
| **EmbeddingService** | Génère les vecteurs (appel API qwen3-embedding) | `EmbedDocumentJob`, `RagService` |
| **ChunkingService** | Découpe un texte long en fragments | `EmbedDocumentJob` |
| **ScrapingService** | Extrait le contenu d'une page web | `ScrapeLinkJob` |
| **LlmCallService** | Appel LLM ponctuel (sans historique) | `SummarizeDocumentJob`, `TagDocumentJob` |

### Détail de chaque service

#### OpenRouterService — Le chef d'orchestre du chat

```ruby
# Quand l'utilisateur envoie un message :
service = OpenRouterService.new(conversation, user_message)
reponse = service.call
```

Ce qui se passe dans `call` :
1. **RAG** : cherche les documents pertinents dans pgvector
2. **Prompt enrichi** : construit un prompt système avec le contexte documentaire
3. **Appel LLM** : envoie tout à OpenRouter
4. **Fallback** : si le modèle principal est rate-limité, essaie le suivant

#### RagService — Le moteur de recherche intelligent

```ruby
rag = RagService.new(user)
chunks = rag.search("c'est quoi le ML ?", limit: 5)
# → cherche les 5 chunks les plus proches sémantiquement

contexte = rag.format_context(chunks)
# → formate : "[Document: titre]\ncontenu..."
```

La méthode `search` utilise `nearest_neighbors` de la gem `neighbor` qui fait une
recherche par **similarité cosinus** dans pgvector.

#### EmbeddingService — Du texte aux mathématiques

```ruby
vecteur = EmbeddingService.embed("Le machine learning...")
# → [0.0123, -0.0456, 0.0789, ...] (1024 nombres)
```

Le modèle utilisé est **qwen3-embedding-8b** via OpenRouter. Il produit des vecteurs
de 4096 dimensions, mais on les tronque à 1024 via une technique appelée
**Matryoshka Representation Learning (MRL)** qui préserve la qualité sémantique.

Pourquoi 1024 ? Parce que l'index HNSW de pgvector est limité à 2000 dimensions.

---

## Les jobs asynchrones

Les **jobs** sont des tâches qui s'exécutent en arrière-plan via **Solid Queue**.
Ils évitent de bloquer l'utilisateur pendant des opérations longues (appels API).

| Job | Queue | Déclenché par | Ce qu'il fait |
|-----|-------|--------------|---------------|
| **EmbedDocumentJob** | `ai` | Création/modification d'un document | Découpe le contenu, génère les vecteurs, les stocke |
| **ScrapeLinkJob** | `ai` | Création d'un document "Lien" avec URL | Télécharge et extrait le contenu de la page web |
| **SummarizeDocumentJob** | `ai` | Chaîné par EmbedDocumentJob | Demande à l'IA de résumer le document en 3 phrases |
| **TagDocumentJob** | `ai` | Chaîné par EmbedDocumentJob | Demande à l'IA de suggérer 3-5 mots-clés |

### Chaînage des jobs

```
Document créé
    │
    ▼
EmbedDocumentJob
    │
    ├──► ChunkingService (découpe)
    ├──► EmbeddingService (vecteurs)
    │
    ├──► SummarizeDocumentJob (résumé IA)
    └──► TagDocumentJob (tags IA)
```

> 💡 **Pourquoi asynchrone ?** Les appels à l'API OpenRouter prennent 1 à 5 secondes.
> Sans jobs asynchrones, l'utilisateur verrait un écran blanc pendant ce temps.

---

## Les APIs externes

Toute l'intelligence artificielle passe par **OpenRouter**, un service qui donne
accès à des dizaines de modèles d'IA via une seule API.

| Usage | Modèle | Endpoint |
|-------|--------|----------|
| **Chat (LLM)** | `deepseek/deepseek-v4-flash` (prod) ou `nvidia/nemotron-3-super-120b-a12b:free` (dev) | `/chat/completions` |
| **Embeddings** | `qwen/qwen3-embedding-8b` | `/embeddings` |
| **TTS** (texte → audio) | `hexgrad/kokoro-82m` | `/audio/speech` |
| **STT** (audio → texte) | `openai/whisper-large-v3-turbo` | `/audio/transcriptions` |

### Pourquoi OpenRouter ?

- **Un seul compte** pour tous les modèles (pas besoin de comptes OpenAI + Anthropic + ...)
- **Modèles gratuits** disponibles pour le développement
- **Fallback automatique** : si un modèle est rate-limité, on peut essayer le suivant

### Sécurité

⚠️ **La clé API n'est jamais exposée au navigateur.** Tous les appels aux APIs
externes passent par le serveur Rails (controllers `TtsController` et
`TranscriptionsController`). Le front-end ne communique qu'avec le back-end.

---

## Les tests

```
148 tests, 262 assertions, 0 échec
```

### Structure des tests

```
test/
├── models/           # Tests des modèles (validations, associations, callbacks)
│   ├── user_test.rb
│   ├── folder_test.rb
│   ├── document_test.rb
│   ├── document_chunk_test.rb
│   ├── conversation_test.rb
│   ├── message_test.rb
│   ├── tag_test.rb
│   └── tagging_test.rb
├── controllers/      # Tests des contrôleurs (HTTP, auth, réponses)
│   ├── pages_controller_test.rb
│   ├── faqs_controller_test.rb
│   ├── espaces_controller_test.rb
│   ├── conversations_controller_test.rb
│   ├── messages_controller_test.rb
│   ├── documents_controller_test.rb
│   ├── folders_controller_test.rb
│   ├── searches_controller_test.rb
│   ├── tts_controller_test.rb
│   └── transcriptions_controller_test.rb
├── services/         # Tests des services (logique métier)
│   ├── chunking_service_test.rb
│   ├── embedding_service_test.rb
│   ├── rag_service_test.rb
│   ├── scraping_service_test.rb
│   ├── llm_call_service_test.rb
│   └── open_router_service_test.rb
├── jobs/             # Tests des jobs (exécution asynchrone)
│   ├── embed_document_job_test.rb
│   ├── scrape_link_job_test.rb
│   ├── summarize_document_job_test.rb
│   └── tag_document_job_test.rb
└── fixtures/         # Données de test
    └── users.yml
```

### Lancer les tests

```bash
bin/rails test                              # Tous les tests
bin/rails test test/models/document_test.rb # Un fichier spécifique
bin/rails test test/models/document_test.rb:12  # Un test spécifique (ligne 12)
```

---

## Déploiement

Le projet est conçu pour être déployé sur **Heroku** (budget étudiant ~$12/mois).

### Configuration Heroku

```bash
# Créer l'app
heroku create mindsnap

# Ajouter PostgreSQL
heroku addons:create heroku-postgresql:essential-0

# Activer pgvector (une seule fois après le déploiement)
heroku run rails runner "ActiveRecord::Base.connection.execute('CREATE EXTENSION IF NOT EXISTS vector')"

# Configurer les variables d'environnement
heroku config:set OPENROUTER_API_KEY=sk-or-v1-...
heroku config:set OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
heroku config:set CLOUDINARY_URL=cloudinary://...

# Déployer
git push heroku master
heroku run rails db:migrate
```

### Installation manuelle de pgvector (PostgreSQL 15)

Sur macOS, le bottle Homebrew de pgvector ne cible que PostgreSQL 17+.
Si tu utilises PostgreSQL 15 :

```bash
cd /tmp
git clone --branch v0.8.2 https://github.com/pgvector/pgvector.git
cd pgvector
export PG_CONFIG=/opt/homebrew/opt/postgresql@15/bin/pg_config
make clean && make && make install
```

---

## Ressources pour apprendre

### Pour comprendre les concepts

| Concept | Ressource |
|---------|-----------|
| **RAG** (Retrieval Augmented Generation) | [What is RAG? (IBM)](https://research.ibm.com/blog/retrieval-augmented-generation-RAG) |
| **Embeddings vectoriels** | [Vector Embeddings Explained (Weaviate)](https://weaviate.io/blog/vector-embeddings-explained) |
| **pgvector** | [pgvector GitHub](https://github.com/pgvector/pgvector) |
| **MVC (Modèle-Vue-Contrôleur)** | [Rails Guides: Getting Started](https://guides.rubyonrails.org/getting_started.html) |
| **Hotwire / Turbo** | [Hotwire.dev](https://hotwired.dev/) |
| **Solid Queue** | [Solid Queue GitHub](https://github.com/rails/solid_queue) |

### Documentation des gems utilisées

| Gem | Documentation |
|-----|--------------|
| **neighbor** (pgvector pour Rails) | [github.com/ankane/neighbor](https://github.com/ankane/neighbor) |
| **devise** (authentification) | [github.com/heartcombo/devise](https://github.com/heartcombo/devise) |
| **faraday** (client HTTP) | [lostisland.github.io/faraday](https://lostisland.github.io/faraday/) |
| **nokogiri** (parsing HTML) | [nokogiri.org](https://nokogiri.org/) |
| **mission_control-jobs** (dashboard jobs) | [github.com/rails/mission_control-jobs](https://github.com/rails/mission_control-jobs) |

### OpenRouter

- [Documentation API](https://openrouter.ai/docs)
- [Modèles disponibles](https://openrouter.ai/models)
- [Obtenir une clé API](https://openrouter.ai/keys)

---

## Roadmap

### ✅ Fait (session du 2026-06-03)

- [x] pgvector + embeddings vectoriels (1024 dimensions)
- [x] Découpage intelligent des documents (chunking)
- [x] RAG : l'IA répond en s'appuyant sur les documents
- [x] Scraping automatique des liens
- [x] Résumé automatique par l'IA
- [x] Tags automatiques
- [x] Chat contextuel par dossier
- [x] Recherche sémantique unifiée
- [x] Voice : dictée vocale (STT) + lecture audio (TTS)
- [x] 148 tests automatisés

### 🔮 Idées pour la suite

- [ ] Streaming des réponses LLM (mot par mot)
- [ ] Reranker pour améliorer la pertinence des recherches
- [ ] Extension navigateur (Chrome/Firefox)
- [ ] Mode hors-ligne avec modèles locaux (Ollama)
- [ ] Export des conversations en PDF/Markdown
- [ ] Partage de documents entre utilisateurs
- [ ] OCR pour extraire le texte des images et PDFs

---

## Équipe

Projet étudiant réalisé par l'équipe MindSnap.

**Stack** : Ruby on Rails 8.1.3, PostgreSQL + pgvector, Hotwire, Bootstrap 5.3, OpenRouter API.

**Contact** : [GitHub](https://github.com/G2025-mahfoudhi/mindSnap)

---

*« La connaissance, c'est le pouvoir. Mais la connaissance organisée et accessible, c'est un super-pouvoir. »*
