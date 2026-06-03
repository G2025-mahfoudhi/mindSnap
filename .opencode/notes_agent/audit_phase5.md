# Notes d'audit — Phase 5 (Final)

## 2026-06-03 — Déploiement des 5 phases

### Statistiques finales

| Catégorie | Nombre |
|-----------|:------:|
| Modèles | 9 |
| Contrôleurs | 11 |
| Services | 6 |
| Jobs | 5 |
| Migrations | 20 (dont 6 nouvelles) |
| Contrôleurs Stimulus | 10 |
| Tests | 57 runs, 90 assertions, 0 failures |
| Fichiers de test | 17 |

### Arborescence des nouveaux fichiers

```
app/
├── models/
│   ├── document_chunk.rb      # pgvector has_neighbors
│   ├── tag.rb                 # tags auto-générés
│   └── tagging.rb             # polymorphic join
├── controllers/
│   ├── searches_controller.rb # recherche sémantique
│   ├── tts_controller.rb      # proxy Kokoro TTS
│   └── transcriptions_controller.rb  # proxy Whisper STT
├── services/
│   ├── embedding_service.rb   # qwen3-embedding → 1024-dim
│   ├── chunking_service.rb    # split 512 tokens
│   ├── rag_service.rb         # pgvector nearest_neighbors
│   ├── scraping_service.rb    # Nokogiri HTML extraction
│   └── llm_call_service.rb    # oneshot LLM prompts
├── jobs/
│   ├── embed_document_job.rb
│   ├── scrape_link_job.rb
│   ├── summarize_document_job.rb
│   └── tag_document_job.rb
├── views/
│   └── searches/index.html.erb
└── javascript/controllers/
    └── voice_controller.js
```

### Fichiers modifiés

- `Gemfile` — ajout faraday, nokogiri, neighbor, mission_control-jobs; retrait ruby_llm
- `app/models/document.rb` — after_commit embed_async + scrape_async
- `app/models/conversation.rb` — polymorphic context
- `app/models/user.rb` — has_many :tags
- `app/services/open_router_service.rb` — RAG context + prompt enrichi
- `app/controllers/folders_controller.rb` — action chat
- `app/views/messages/_message.html.erb` — bouton TTS
- `app/views/conversations/show.html.erb` — voice controller + bouton micro
- `app/views/folders/show.html.erb` — bouton "Discuter"
- `app/views/shared/_document_card.html.erb` — résumé, tags, badge scraping
- `app/views/shared/_navbar.html.erb` — lien Recherche
- `config/routes.rb` — +search, +tts, +transcribe, +folder chat, -new conversations

### Décisions techniques

| Décision | Détail |
|----------|--------|
| Embedding 1024-dim | HNSW pgvector limité à 2000 dims. 4096 → tronqué via MRL |
| LLM via Faraday | OpenRouterService utilise Faraday; LlmCallService utilise Net::HTTP |
| ruby_llm retiré | Remplacé par intégration directe Faraday/Net::HTTP |
| Pas de `:new` sur conversations | L'UX crée les conversations via dashboard ou folder chat |
| pgvector compilé manuellement | Pour PG15 (non supporté par brew bottle) |

### Ce qui reste à tester manuellement

- [x] Phase 1: création document → embedding vectoriel
- [x] Phase 2: question → RAG search → contexte
- [x] Phase 3: scraping, résumé, tags
- [x] Phase 4: chat dossier, recherche sémantique
- [ ] Phase 5: STT (enregistrement micro → transcription)
- [ ] Phase 5: TTS (lecture audio des réponses)
