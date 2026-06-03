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
- **Folder** — self-referential tree: a folder belongs to a parent `Folder` (optional) and has many children. The FK in the DB is `folder_id` but the model association uses the alias `parent` / `children` with `foreign_key: 'parent_id'`. Has many documents.
- **Document** — belongs to a user and a folder. Has `title`, `content`, `type` (Rails STI column), and `date_injection`. The `type` column activates Rails Single Table Inheritance — subclass appropriately rather than setting it as a plain string.
- **Conversation** — belongs to a user, has many messages.
- **Message** — belongs to a conversation. `role` column distinguishes speaker (e.g. `"user"` / `"assistant"`).

### Known issues in the current codebase (as of branch `controller-document`)

- `User` model has two syntax errors: `has many` (missing underscore) for conversations and messages — these need fixing before the app boots cleanly.
- `Folder` model has `belongs_to :parent` declared twice; the first (generic) call should be removed.
- `DocumentsController` has incomplete/placeholder implementations (`new`, `create`) that reference wrong associations and a non-existent `chat_path`.

### Authentication

`ApplicationController` enforces `before_action :authenticate_user!` globally. Controllers that should be publicly accessible must override with `skip_before_action :authenticate_user!`.

### Background jobs / caching

Solid Queue (jobs), Solid Cache (Rails.cache), and Solid Cable (Action Cable) are configured — all backed by PostgreSQL, no Redis required.

### Deployment

Kamal is configured (`config/deploy.yml`). Production uses `MIND_SNAP_DATABASE_PASSWORD` env var.

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
