# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Setup
bin/setup                        # install deps, create & migrate DB, seed

# Development server
bin/dev                          # start Rails + asset watchers

# Database
bin/rails db:migrate             # run pending migrations
bin/rails db:seed                # seed the database
# Note: db/queue_schema.rb est regen automatiquement par Solid Queue au
# démarrage du serveur. Si git montre un diff sur ce fichier après un
# bin/rails db:migrate, c'est normal — commit tel quel (c'est un dump
# complet des tables solid_queue_*, pas une migration manuelle).

# Tests
bin/rails test                              # run all tests
bin/rails test test/models/user_test.rb    # run a single test file
bin/rails test test/models/user_test.rb:12 # run a single test by line

# Linting & security
bin/rubocop                      # lint Ruby (rubocop-rails-omakase style)
bin/brakeman                     # static security analysis
bin/bundler-audit                # audit gems for known CVEs
bin/ci                           # runs all of the above together
```

## Architecture

Rails 8.1.3 app (Ruby 3.3.5) bootstrapped from the [Le Wagon template](https://github.com/lewagon/rails-templates). PostgreSQL database. Hotwire (Turbo + Stimulus) for interactivity. Bootstrap 5.3 + Simple Form for UI. Assets served via Sprockets + importmap (no Node/Webpack).

### Domain model

The app is a knowledge-management tool where users organize documents into folders and chat with an AI about them.

- **User** — authenticated via Devise. Owns folders, documents, and conversations.
- **Folder** — self-referential tree: belongs to a parent `Folder` (optional), has many children. FK is `parent_id`. Has many documents.
- **Document** — belongs to a user and an optional folder. Has `title`, `content`, `document_type`, `date_injection`. Uses `has_many_attached :file` (Active Storage) for file uploads stored on Cloudinary in production. Note: the column is `document_type`, NOT `type` (STI was intentionally avoided — a migration renamed it).
- **Conversation** — belongs to a user, has many messages.
- **Message** — belongs to a conversation. `role` column is `"user"` or `"assistant"`.

### Authentication

`ApplicationController` enforces `before_action :authenticate_user!` globally. Controllers that should be publicly accessible must override with `skip_before_action :authenticate_user!`.

### Background jobs / caching

Solid Queue (jobs), Solid Cache (Rails.cache), and Solid Cable (Action Cable) are configured — all backed by PostgreSQL, no Redis required.

### Deployment

Heroku (`our-mindsnap`). Kamal est aussi configuré (`config/deploy.yml`).
Variables d'environnement requises en production :
```
CLOUDINARY_URL=cloudinary://API_KEY:API_SECRET@mindsnap
OPENROUTER_API_KEY=sk-or-v1-...
OPENROUTER_MODEL=nvidia/nemotron-3-nano-30b-a3b:free
```
Après chaque deploy : `heroku run rails db:migrate --app our-mindsnap`

---

## Session du 2026-06-03 — Intégration OpenRouter pour la messagerie

### Ce qui a été implémenté

**`app/services/open_router_service.rb`** (nouveau)
- Service qui appelle l'API OpenRouter via Faraday (pas de gem supplémentaire).
- Envoie l'historique de la conversation (18 derniers messages) + un prompt système.
- Logique de fallback : essaie plusieurs modèles dans l'ordre si le premier est rate-limité.
- Modèles dans `FALLBACK_MODELS` : `nvidia/nemotron-3-nano-30b-a3b:free`, `nvidia/nemotron-3-super-120b-a12b:free`, `poolside/laguna-xs.2:free`, `google/gemma-4-26b-a4b-it:free`.
- Modèle actif configurable via `OPENROUTER_MODEL` dans `.env`.

**`app/controllers/messages_controller.rb`** (réécrit)
- Remplace l'ancienne intégration `RubyLLM` par `OpenRouterService`.
- Si l'IA échoue, un message d'erreur friendly est sauvegardé dans la conversation plutôt que de rediriger.

**`app/controllers/conversations_controller.rb`** (modifié)
- `show` charge maintenant `@conversations` (nécessaire pour la sidebar).

**`app/views/messages/_message.html.erb`** (nouveau)
- Bulle de chat : messages utilisateur à droite (fond bleu), réponses IA à gauche (fond clair).
- Utilise `simple_format` pour respecter les sauts de ligne.

**`app/views/messages/create.turbo_stream.erb`** (nouveau)
- Ajoute les deux messages (user + AI) dans `#messages` sans rechargement.
- Réinitialise le formulaire via `turbo_stream.replace "new_message_form"`.

**`app/views/conversations/show.html.erb`** (réécrit)
- Layout complet : sidebar gauche + zone chat flex-column (header / messages scrollables / formulaire bas).
- Utilise le partiel `conversations/_sidebar` existant.
- Connecte le contrôleur Stimulus `chat-scroll` sur le div `#messages`.

**`app/javascript/controllers/chat_scroll_controller.js`** (nouveau)
- Scroll automatique vers le bas à l'ouverture et à chaque nouveau message (MutationObserver).

### Variables d'environnement requises (`.env`)
```
OPENROUTER_API_KEY=sk-or-v1-...   # clé OpenRouter (openrouter.ai/keys)
OPENROUTER_MODEL=nvidia/nemotron-3-nano-30b-a3b:free  # modèle par défaut
```

### Points de vigilance
- Les modèles gratuits OpenRouter sont souvent rate-limités — c'est pourquoi le fallback existe.
- `ruby_llm` est toujours dans le Gemfile mais n'est plus utilisé ; il peut être retiré.
- Le prompt système instruit l'IA de répondre à tout message (y compris les salutations) tout en ramenant la conversation vers les documents de l'utilisateur.

---

## Session du 2026-06-03 — UI conversations + téléchargement Cloudinary

### Interface conversations (show & index)

**`app/views/conversations/show.html.erb`** (réécrit)
- Layout : sidebar + zone chat (`d-flex`, hauteur `calc(100vh - 56px - 4rem)`).
- État vide affiché quand pas encore de message.
- Formulaire en bas avec textarea autoresize + bouton "Envoyer" responsive (`d-none d-md-inline`).

**`app/views/conversations/index.html.erb`** (réécrit)
- Même hauteur que show. Zone centrale avec état vide et bouton "Nouvelle conversation".

**`app/views/messages/_message.html.erb`** (nouveau)
- Bulles : utilisateur à droite (`bg-primary`), IA à gauche (`bg-light`).

**`app/views/messages/create.turbo_stream.erb`** (nouveau)
- Append des deux messages + reset formulaire via `turbo_stream.replace`.
- Utilise `f.text_area` directement (bypasse le wrapper simple_form qui causait un désalignement).

**`app/javascript/controllers/chat_scroll_controller.js`** (nouveau)
- MutationObserver : scroll automatique vers le bas à chaque nouveau message.

**`app/javascript/controllers/textarea_autoresize_controller.js`** (nouveau)
- Auto-resize de la textarea. Ajoute les bordures au `scrollHeight` (correction box-sizing).

**`app/javascript/controllers/draggable_controller.js`** (modifié)
- Ajout d'un listener `resize` : repositionne le bouton flottant quand l'écran change de taille.
- Si la position sauvegardée sort de l'écran → `resetToDefault()` (retour en `bottom: 6rem; right: 1.5rem`).

**`app/views/layouts/application.html.erb`** (modifié)
- Body en `d-flex flex-column min-vh-100` avec `padding-bottom: 3rem` pour le footer fixe.

### Téléchargement de fichiers depuis Cloudinary

**`config/storage.yml`**
- Ajout de `resource_type: auto` pour que Cloudinary accepte tous les types de fichiers.

**`config/routes.rb`**
- Ajout d'une route `member get :download` sur les documents.

**`app/controllers/documents_controller.rb`**
- Nouvelle action `download` : génère une URL Cloudinary valide via `Cloudinary::Utils.cloudinary_url` avec le bon `resource_type` selon le `content_type`.
- Méthode privée `cloudinary_resource_type` : `image/` → `image`, `video/` → `video`, `application/pdf` → `image`, reste → `raw`.
- Flag `fl_attachment:nom_sans_extension_sans_espaces` : l'extension `.pdf` dans le flag causait un 400 (interprétée comme format par Cloudinary), les espaces cassaient l'URL.

**`app/views/documents/show.html.erb`**
- Lien téléchargement → `download_document_path(@document, blob_signed_id: attachment.blob.signed_id)`.

### Bugs critiques corrigés
- `@document.file.purge` dans `document_path(...)` — appelé à chaque chargement de page, supprimait tous les fichiers Cloudinary. Corrigé en `document_path(@document)`.
- `@document.file.key` dans la route download — `file` est une collection, `.key` n'existe pas. Corrigé en `@document`.

### Production Heroku
- Migrations jamais lancées → `heroku run rails db:migrate` (500 sur toutes les pages).
- `CLOUDINARY_URL` avait le mauvais `cloud_name` (`dpm4v9e57` au lieu de `mindsnap`) → uploads échouaient silencieusement.
- Branche `download` déployée via `git push heroku download:master`.

---

## Session du 2026-06-04 — Corrections massives & extraction fichiers

### Modèle OpenRouter
- **Principal** : `deepseek/deepseek-v4-flash` (~0.10 $/M tokens)
- Compte : 5 $ de crédits, ~4.9995 $ restants
- Les modèles `:free` limités à 50 reqs/jour → **tous les fallback sont passés en payant**
- 3 modèles fallback : `deepseek/deepseek-v4-flash`, `nvidia/nemotron-3-nano-30b-a3b:free`, `google/gemma-4-26b-a4b-it:free`

### Infrastructure
- **Solid Queue** configuré en dev : `config.active_job.queue_adapter = :solid_queue` dans `development.rb`
- `SOLID_QUEUE_IN_PUMA=1` dans `.env` → worker in-process Puma (pas de Procfile.dev requis)
- Rôle `queue:` ajouté dans `config/database.yml` (dev)
- MissionControl::Jobs monté sur `/jobs` (`config/routes.rb:2`)

### Services API — Robustesse
- **`app/services/llm_call_service.rb`** : refacto Faraday, headers HTTP-Referer/X-Title, fallback 3 modèles, timeout 30s, nil-check body
- **`app/services/embedding_service.rb`** : refacto Faraday, fallback 2 modèles (`qwen3-embedding-8b` + `e5-mistral`), rescue réseau
- **`app/services/open_router_service.rb`** : rescue Faraday::Error, nil-check, timeout 30s
- **`app/services/file_extraction_service.rb`** (NOUVEAU) : routeur MIME → `pdf-reader`, `docx`, `rtesseract`, texte brut
- **`app/services/scraping_service.rb`** : timeout HTTP (open 5s, read 10s)

### Extraction de texte (NOUVEAU)
- **Gems** : `pdf-reader` 2.15.1, `docx` 0.13.0, `rtesseract` 3.1.4
- **`app/jobs/extract_text_job.rb`** (NOUVEAU) : extrait le texte de tous les fichiers joints, met à jour `content`
- Callback dans `Document` : `after_commit :extract_text_async, on: :create, if: :should_extract_text?`
- **BUG CRITIQUE** : `Tempfile.new` doit utiliser `binmode: true` pour éviter `Encoding::UndefinedConversionError` sur les bytes UTF-8
- Pipeline complet : upload → ExtractTextJob → content → EmbedDocumentJob → SummarizeDocumentJob + TagDocumentJob

### Jobs — Fiabilité
- **`app/jobs/application_job.rb`** : `retry_on` (Deadlock, timeout) + `discard_on` (DeserializationError)
- **`app/jobs/embed_document_job.rb`** : transaction atomique (build puis swap, pas de `destroy_all` avant)
- **`app/jobs/scrape_link_job.rb`** : rescue `RecordNotFound` séparé, `update_all` dans rescue
- **`app/jobs/summarize_document_job.rb`** : stocke message d'erreur si API échoue (pour polling)

### Résumé IA — Affichage & interaction
- **`app/views/documents/_summary.html.erb`** (NOUVEAU) : partial avec `id="doc-summary"`, bouton "Régénérer", polling Stimulus
- **`app/views/documents/show.html.erb`** : render le partial + section tags IA
- **`app/javascript/controllers/summary_poll_controller.js`** (NOUVEAU) : poll `/summary_status` toutes les 3s, timeout 60s avec feedback
- Route `post :summarize` → lance `ExtractTextJob` si contenu vide + fichier attaché
- Route `get :summary_status` → JSON `{ summary: "..." }`

### STT / TTS — Corrections
- **`app/controllers/tts_controller.rb`** : `ENV.fetch('OPENROUTER_API_KEY')` fail-fast, rescue réseau → 503
- **`app/controllers/transcriptions_controller.rb`** : idem
- **`app/javascript/controllers/voice_controller.js`** :
  - CSRF token dans `fetch()`, feedback visuel micro (`is-recording`), garde anti-double-clic TTS
  - `revokeObjectURL` sur `ended` + `error`, `blobToBase64` sécurisé
- **`app/views/conversations/show.html.erb`** : `data-controller="voice"` sur ancêtre commun (hors formulaire)
- **`app/views/messages/create.turbo_stream.erb`** : formulaire remplacé inclut `voice_target`, micro, action clearInput

### Tests
- 170 tests, 0 échec
- Tests mockés pour `LlmCallService`, `SummarizeDocumentJob`, `FileExtractionService`, `ExtractTextJob`

### .env actuel
```
CLOUDINARY_URL=cloudinary://...
OPENROUTER_API_KEY=sk-or-v1-...
OPENROUTER_MODEL=deepseek/deepseek-v4-flash
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
SOLID_QUEUE_IN_PUMA=1
```
