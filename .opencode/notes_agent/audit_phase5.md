# Notes d'audit — Phase 5

## 2026-06-03 — Revue finale du codebase

### Architecture

```
app/
├── controllers/ (9)
│   ├── messages_controller.rb         → OpenRouterService (chat)
│   ├── conversations_controller.rb    → CRUD conversations
│   ├── folders_controller.rb          → CRUD + chat (folder-scoped conv)
│   ├── documents_controller.rb        → CRUD documents
│   ├── searches_controller.rb         → recherche sémantique (Phase 4)
│   ├── tts_controller.rb              → proxy Kokoro TTS (Phase 5)
│   ├── transcriptions_controller.rb   → proxy Whisper STT (Phase 5)
│   ├── espaces_controller.rb          → dashboard
│   └── pages_controller.rb            → landing page
│
├── models/ (8)
│   ├── user.rb          → has_many: documents, folders, conversations, tags
│   ├── document.rb      → after_commit: embed_async, scrape_async
│   ├── document_chunk.rb → has_neighbors :embedding (pgvector)
│   ├── folder.rb        → belongs_to :parent (tree)
│   ├── conversation.rb  → belongs_to :context (polymorphic)
│   ├── message.rb       → role: user/assistant
│   ├── tag.rb           → belongs_to :user
│   └── tagging.rb       → polymorphic
│
├── services/ (5)
│   ├── open_router_service.rb  → chat LLM + RAG + fallback
│   ├── rag_service.rb          → search vectoriel + format contexte
│   ├── embedding_service.rb    → qwen3-embedding (1024-dim via MRL)
│   ├── chunking_service.rb     → split paragraphes (512 tokens, 64 overlap)
│   ├── scraping_service.rb     → Nokogiri HTML extraction
│   └── llm_call_service.rb     → oneshot LLM prompts
│
├── jobs/ (4)
│   ├── embed_document_job.rb      → queue :ai
│   ├── scrape_link_job.rb         → queue :ai
│   ├── summarize_document_job.rb  → queue :ai
│   └── tag_document_job.rb        → queue :ai
│
└── javascript/controllers/ (8)
    ├── voice_controller.js (Phase 5)
    ├── chat_scroll_controller.js
    ├── textarea_autoresize_controller.js
    ├── draggable_controller.js
    ├── faq_search_controller.js
    ├── document_type_controller.js
    └── folder_select_controller.js
```

### Problèmes identifiés

1. **🟡 Route `:new` sur conversations** — Le contrôleur n'a pas d'action `new`. La route `/conversations/new` lèvera une erreur 404. Pas critique car l'UX ne passe jamais par cette URL (conversations créées via dashboard ou folder chat).

2. **🔴 Dépendances implicites** — `Faraday` et `Nokogiri` ne sont PAS dans le Gemfile. Ils sont chargés comme dépendances transitives de `ruby_llm`. À ajouter explicitement.

3. **🟡 `ruby_llm` non utilisé** — La gem est installée mais plus utilisée (remplacée par `OpenRouterService` Faraday + `LlmCallService` Net::HTTP). À supprimer.

4. **🟢 Cloudinary** — Utilisé en production pour ActiveStorage. La gem doit rester.

5. **🟢 APIs OpenRouter** — Les endpoints `/audio/speech` (Kokoro) et `/audio/transcriptions` (Whisper) doivent être vérifiés contre la doc officielle.

### Tests

- **57 tests, 90 assertions, 0 failures** (hors 3 erreurs pré-existantes FoldersControllerTest)
- Couverture : modèles (Document, DocumentChunk, Conversation, Tag, Tagging), services (ChunkingService, RagService, ScrapingService), contrôleurs (Searches)
- Manque : tests TtsController, TranscriptionsController, voice_controller

### À faire avant merge

- [x] Ajouter `has_many :tags` sur User
- [ ] Ajouter `faraday` et `nokogiri` explicitement au Gemfile
- [ ] Supprimer `ruby_llm` du Gemfile
- [ ] Retirer `:new` de la route conversations OU ajouter l'action `new`
- [ ] Tests TtsController + TranscriptionsController
- [ ] Vérifier les endpoints API OpenRouter exacts
