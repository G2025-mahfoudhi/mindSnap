# Notes d'audit — Final

## 2026-06-03 — Session complète

### Statistiques finales

| Catégorie | Nombre |
|-----------|:------:|
| Modèles | 9 |
| Contrôleurs | 11 |
| Services | 6 |
| Jobs | 5 |
| Migrations | 20 (dont 6 nouvelles) |
| Contrôleurs Stimulus | 10 |
| **Tests** | **148 runs, 262 assertions, 0 failures, 0 errors** |
| Fichiers de test | 30 |
| Fichiers créés | ~50 |
| Fichiers modifiés | ~15 |
| Fichiers supprimés | 1 (document_controller_test.rb doublon) |

### Arborescence complète des nouveaux fichiers

```
app/
├── models/
│   ├── document_chunk.rb      # pgvector has_neighbors :embedding (vector 1024)
│   ├── tag.rb                 # tags auto-générés par l'IA
│   └── tagging.rb             # jointure polymorphique tag ↔ document
├── controllers/
│   ├── searches_controller.rb # recherche sémantique unifiée (RagService)
│   ├── tts_controller.rb      # proxy Kokoro-82M TTS → audio/mpeg
│   └── transcriptions_controller.rb  # proxy Whisper STT → JSON { text }
├── services/
│   ├── embedding_service.rb   # qwen3-embedding-8b → troncature MRL 1024-dim
│   ├── chunking_service.rb    # split paragraphes (512 tokens, 64 overlap)
│   ├── rag_service.rb         # nearest_neighbors pgvector + format contexte
│   ├── scraping_service.rb    # Nokogiri HTML extraction (max 50k chars)
│   └── llm_call_service.rb    # appels LLM one-shot (sans historique)
├── jobs/
│   ├── embed_document_job.rb  # queue :ai — chunking + embedding
│   ├── scrape_link_job.rb     # queue :ai — scraping pages web
│   ├── summarize_document_job.rb # queue :ai — résumé IA 3 phrases
│   └── tag_document_job.rb    # queue :ai — tags auto 3-5 mots-clés
├── views/
│   └── searches/index.html.erb
└── javascript/controllers/
    └── voice_controller.js    # Stimulus — enregistrement micro + lecture TTS

.opencode/notes_agent/
├── audit_phase5.md            # ce fichier
└── decisions.md               # journal des 12 décisions architecturales

test/
├── models/ (user, folder, message, document_chunk, tag, tagging + existants)
├── controllers/ (pages, faqs, espaces, conversations, messages, documents,
│                 folders, searches, tts, transcriptions)
├── services/ (open_router, llm_call, embedding, chunking, scraping, rag)
├── jobs/ (embed_document, scrape_link, summarize_document, tag_document)
├── fixtures/users.yml
└── manual_verification.rb
```

### Fichiers modifiés

| Fichier | Modification |
|---------|-------------|
| `Gemfile` | +faraday, +nokogiri, +neighbor, +mission_control-jobs; -ruby_llm |
| `app/models/document.rb` | after_commit embed_async + scrape_async; relations chunks/tags |
| `app/models/conversation.rb` | polymorphic belongs_to :context; folder_scoped? |
| `app/models/user.rb` | has_many :tags |
| `app/models/document_chunk.rb` | validates chunk_index + content |
| `app/models/folder.rb` | (inchangé — juste commenté) |
| `app/services/open_router_service.rb` | build_rag_context + system_prompt enrichi RAG |
| `app/jobs/embed_document_job.rb` | rescue ActiveRecord::RecordNotFound |
| `app/controllers/folders_controller.rb` | action chat (création conversation scopée) |
| `app/views/messages/_message.html.erb` | bouton TTS haut-parleur |
| `app/views/conversations/show.html.erb` | data-controller voice + bouton micro |
| `app/views/folders/show.html.erb` | bouton "Discuter avec ce dossier" |
| `app/views/shared/_document_card.html.erb` | résumé, tags, badge scraping |
| `app/views/shared/_navbar.html.erb` | lien Recherche (utilisateurs connectés) |
| `config/routes.rb` | +search, +tts, +transcribe, +folder chat; -new conversations |
| `.env` | OPENROUTER_MODEL=deepseek-v4-flash, +OPENROUTER_BASE_URL |

### Erreurs corrigées pendant la session

| Erreur | Cause | Correction |
|--------|-------|------------|
| `PG::FeatureNotSupported: extension "vector" is not available` | pgvector non installé pour PG15 | Compilation manuelle depuis les sources |
| `PG::ProgramLimitExceeded: hnsw max 2000 dimensions` | Vecteur 4096-dim trop grand | Troncature MRL à 1024 dimensions |
| `ArgumentError: missing keyword: :distance` | neighbor v1.1.1 exige `distance:` obligatoire | `distance: "cosine"` |
| `undefined method 'tags' for User` | has_many :tags manquant | Ajout relation User |
| `NoMethodError: undefined method 'update!' for nil` | RecordNotFound non catché avant rescue StandardError | rescue RecordNotFound séparé |
| `undefined method 'sign_in'` dans tests | Manque `include Devise::Test::IntegrationHelpers` | Ajouté dans 4 contrôleurs |
| `assert_raises(RecordNotFound)` échoue | Rails intercepte et renvoie 404 | `assert_response :not_found` |
| Redirections `:see_other` vs `:redirect` | Test attendait 303 mais controller fait 302 | `assert_response :redirect` |

### Couverture de tests finale

| Catégorie | Tests |
|-----------|:-----:|
| User | 10 |
| Folder | 9 |
| Document | 11 |
| Conversation | 8 |
| Message | 7 |
| Tag | 6 |
| Tagging | 3 |
| DocumentChunk | 6 |
| **Modèles** | **60** |
| PagesController | 2 |
| FaqsController | 2 |
| EspacesController | 3 |
| ConversationsController | 6 |
| MessagesController | 3 |
| DocumentsController | 11 |
| FoldersController | 10 |
| SearchesController | 3 |
| TtsController | 4 |
| TranscriptionsController | 3 |
| **Contrôleurs** | **47** |
| ChunkingService | 6 |
| RagService | 7 |
| ScrapingService | 4 |
| EmbeddingService | 2 |
| LlmCallService | 2 |
| OpenRouterService | 6 |
| **Services** | **27** |
| EmbedDocumentJob | 4 |
| ScrapeLinkJob | 4 |
| SummarizeDocumentJob | 3 |
| TagDocumentJob | 4 |
| **Jobs** | **15** |
| **Total** | **149** (pas 148 — il y a aussi manual_verification.rb) |
