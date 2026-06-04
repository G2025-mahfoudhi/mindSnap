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
