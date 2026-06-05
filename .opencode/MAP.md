# 🗺️ MindSnap — Codebase Map

> **Version :** 2.0 | **Dernière mise à jour :** 2026-06-04
> Cartographie exhaustive de tous les fichiers significatifs, leurs rôles et dépendances.

---

## 📦 Stack

- **Framework** : Rails 8.1.3 (Ruby 3.3.5)
- **Base de données** : PostgreSQL 15 + pgvector (HNSW cosine, 1024-dim)
- **Frontend** : Hotwire (Turbo + Stimulus), Bootstrap 5.3, SimpleForm
- **Assets** : Sprockets + importmap (pas de Node/Webpack)
- **Jobs** : Solid Queue (PostgreSQL) — Puma plugin `SOLID_QUEUE_IN_PUMA`
- **Cache** : Solid Cache (PostgreSQL)
- **WebSockets** : Solid Cable (PostgreSQL)
- **Auth** : Devise
- **IA** : OpenRouter API (Faraday), modèle `deepseek/deepseek-v4-flash`
- **Upload** : Active Storage → Cloudinary (prod) / Disk (dev)
- **Déploiement** : Heroku (`our-mindsnap`) + Kamal (configuré, non actif)

---

## `app/models/` — 9 fichiers

| Fichier | Rôle | Dépendances |
|---------|------|-------------|
| `application_record.rb` | Base AR | `ActiveRecord::Base` |
| `user.rb` | Auth Devise, racine associations | `Document`, `Folder`, `Conversation`, `Message` (through), `Tag` |
| `document.rb` | Pipeline central : scrape → extract → embed → summarize → tag | `User`, `Folder`, `DocumentChunk`, `Tagging`, `Tag`, `ActiveStorage`, `ScrapeLinkJob`, `ExtractTextJob`, `EmbedDocumentJob` |
| `folder.rb` | Dossiers auto-référencés (arbre) | `User`, `Folder` (parent/children), `Document` |
| `conversation.rb` | Chat IA, contexte polymorphique | `User`, `Message`, `Folder` (polymorphique) |
| `message.rb` | Message unitaire (user/assistant) | `Conversation` |
| `document_chunk.rb` | Fragment ~512 tokens + vecteur 1024D pgvector | `Document`, gem `neighbor` |
| `tag.rb` | Mot-clé IA, normalisé, scopé user | `User`, `Tagging` |
| `tagging.rb` | Jointure polymorphique Tag ↔ Document | `Tag`, `Document` |

---

## `app/controllers/` — 10 fichiers

| Fichier | Rôle |
|---------|------|
| `application_controller.rb` | Base : Devise, strong params, layouts |
| `documents_controller.rb` | CRUD + download + summarize/summary_status |
| `conversations_controller.rb` | CRUD conversations |
| `messages_controller.rb` | Chat : user msg → AI → Turbo Stream |
| `searches_controller.rb` | Recherche sémantique RAG |
| `folders_controller.rb` | CRUD dossiers + chat contextuel |
| `tts_controller.rb` | Proxy TTS Kokoro-82M → audio MP3 |
| `transcriptions_controller.rb` | Proxy STT Whisper → texte JSON |
| `espaces_controller.rb` | Dashboard arborescence |
| `faqs_controller.rb` | FAQ publique |
| `pages_controller.rb` | Landing page |

---

## `app/services/` — 7 fichiers

| Fichier | Rôle | API |
|---------|------|-----|
| `open_router_service.rb` | Chat IA + RAG + fallback 3 modèles | `/chat/completions` |
| `llm_call_service.rb` | Appel LLM oneshot (résumés/tags) | `/chat/completions` |
| `embedding_service.rb` | Vecteurs 1024D + fallback 2 modèles | `/embeddings` |
| `file_extraction_service.rb` | Routeur MIME → PDF/DOCX/OCR/txt | `pdf-reader`, `docx`, `rtesseract` |
| `rag_service.rb` | Recherche vectorielle pgvector | — |
| `chunking_service.rb` | Découpe texte 512 tokens | — |
| `scraping_service.rb` | Extraction web Nokogiri | — |

---

## `app/jobs/` — 5 fichiers + 1 base

| Fichier | Queue | Rôle |
|---------|-------|------|
| `application_job.rb` | — | `retry_on` Deadlock+timeout, `discard_on` Deserialization |
| `extract_text_job.rb` | `:ai` | Extraction texte fichiers → `document.content` |
| `embed_document_job.rb` | `:ai` | Chunk + embed → pgvector, chaîne Summarize+Tag |
| `scrape_link_job.rb` | `:ai` | Scrape URL → `content` → EmbedDocumentJob |
| `summarize_document_job.rb` | `:ai` | LLM → résumé 3 phrases → `document.summary` |
| `tag_document_job.rb` | `:ai` | LLM → 3-5 tags → `Tag` + `Tagging` |

---

## `app/views/` — 39 fichiers

### `documents/` (8)
| Fichier | Rôle |
|---------|------|
| `show.html.erb` | Détail : header, contenu, résumé IA, tags |
| `_summary.html.erb` | Bloc résumé IA + polling + bouton Régénérer |
| `_form.html.erb` | Formulaire création/édition avec Stimulus |
| `_sidebar.html.erb` | Arborescence dossiers récursive |
| `_folder_node.html.erb` | Nœud récursif sidebar |

### `conversations/` (5)
| `show.html.erb` | Chat : sidebar + messages + formulaire + micro |
| `_sidebar.html.erb` | Liste conversations |
| `_header.html.erb` | En-tête chat |

### `messages/` (2)
| `_message.html.erb` | Bulle chat + bouton TTS |
| `create.turbo_stream.erb` | Turbo Stream : append messages + reset form |

### `shared/` (7)
| `_navbar.html.erb` | Navbar sticky |
| `_footer.html.erb` | Footer fixe |
| `_document_card.html.erb` | Carte document (résumé, tags, statut) |

### `layouts/` (3)
| `application.html.erb` | Layout principal connecté |
| `devise.html.erb` | Layout auth épuré |

---

## `app/javascript/controllers/` — 9 contrôleurs Stimulus

| Fichier | Rôle |
|---------|------|
| `voice_controller.js` | STT (MediaRecorder → /transcribe) + TTS (/tts/speak → Audio) |
| `summary_poll_controller.js` | Polling /summary_status toutes les 3s, timeout 60s |
| `chat_scroll_controller.js` | Auto-scroll messages MutationObserver |
| `faq_search_controller.js` | Recherche FAQ + ScrollSpy IntersectionObserver |
| `document_type_controller.js` | Champs dynamiques selon type document |
| `folder_select_controller.js` | Champ nouveau dossier conditionnel |
| `textarea_autoresize_controller.js` | Auto-resize textarea |
| `draggable_controller.js` | Bouton flottant repositionnable |

---

## `app/assets/stylesheets/` — 16 partials SCSS

| Dossier | Fichiers | Rôle |
|---------|----------|------|
| `config/` | `_colors.scss`, `_fonts.scss`, `_bootstrap_variables.scss` | Variables |
| `components/` | `_navbar.scss`, `_footer.scss`, `_features.scss`, `_hero.scss`, `_how_it_works.scss`, `_alert.scss`, `_avatar.scss`, `_devise.scss`, `_faq.scss` | Composants |
| `pages/` | `_documents.scss`, `_folders.scss`, `_home.scss` | Pages |

---

## `config/` — Fichiers critiques

| Fichier | Rôle |
|---------|------|
| `routes.rb` | Routes : Devise, docs/conversations/messages imbriqués, TTS/STT, MissionControl, health |
| `database.yml` | PostgreSQL multi-bases : primary + queue + cache + cable |
| `queue.yml` | Solid Queue : 1 dispatcher, workers `*`, 3 threads |
| `puma.rb` | Puma + plugin Solid Queue conditionnel |
| `environments/development.rb` | `queue_adapter :solid_queue` + `connects_to` |
| `environments/production.rb` | Cloudinary + Solid Cache + STDOUT logs |
| `storage.yml` | Cloudinary (prod), Disk (dev), Test |
| `importmap.rb` | Bootstrap, Popper, Turbo, Stimulus |

---

## `db/` — 20 migrations

| Catégorie | Migrations |
|-----------|-----------|
| Auth | `devise_create_users` |
| Domain | `create_folders`, `create_documents`, `create_conversations`, `create_messages` |
| Infrastructure | `install_solid_queue`, `install_solid_cache`, `install_solid_cable` |
| Vectors | `enable_pgvector`, `create_document_chunks` |
| Feature | `add_status_to_documents`, `create_tags`, `add_context_to_conversations` |

---

## `test/` — 32 fichiers de test

| Catégorie | Nombre | Fichiers clés |
|-----------|:------:|--------------|
| Modèles | 8 | `document_test.rb`, `user_test.rb` |
| Contrôleurs | 10 | `documents_controller_test.rb` (summarize + status) |
| Jobs | 6 | `extract_text_job_test.rb`, `summarize_document_job_test.rb` (mockés) |
| Services | 7 | `llm_call_service_test.rb` (fallback mocké), `file_extraction_service_test.rb` |

---

## `.env` — Variables requises

```
CLOUDINARY_URL=cloudinary://...
OPENROUTER_API_KEY=sk-or-v1-...
OPENROUTER_MODEL=deepseek/deepseek-v4-flash
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
SOLID_QUEUE_IN_PUMA=1
```

---

## Pipeline complet

```
Création Document
  │
  ├─ type "Lien" + URL → ScrapeLinkJob → ScrapingService → content
  │
  ├─ type "Fichier" + file → ExtractTextJob → FileExtractionService
  │     ├─ PDF natif → pdf-reader
  │     ├─ PDF scanné → pdftoppm → rtesseract
  │     ├─ DOCX → docx gem
  │     ├─ Image → rtesseract
  │     └─ TXT/MD → lecture directe
  │
  └─ content présent → after_commit :embed_async
        │
        └─ EmbedDocumentJob
              ├─ ChunkingService → chunks ~512 tokens
              ├─ EmbeddingService → vecteurs 1024D → pgvector
              ├─ SummarizeDocumentJob → LLM → document.summary
              └─ TagDocumentJob → LLM → tags

Chat IA
  └─ MessagesController
        └─ OpenRouterService
              ├─ RagService.search (pgvector cosine)
              └─ POST /chat/completions (deepseek-v4-flash)

Recherche
  └─ SearchesController
        └─ RagService.search (pgvector nearest_neighbors)

STT : voice_controller.js → /transcribe → Whisper → texte
TTS : voice_controller.js → /tts/speak → Kokoro-82M → audio MP3
```

---

**Statistiques** : 210+ fichiers cartographiés | 170 tests | 0 échec | modèle deepseek-v4-flash
