# Plan Features — MindSnap v2

> **Date** : 2026-06-03
> **Stack** : Rails 8.1.3 / Ruby 3.3.5 / PostgreSQL + pgvector / Hotwire / Bootstrap 5.3
> **LLM** : OpenRouter (`deepseek/deepseek-v4-flash`)
> **Embeddings** : OpenRouter (`qwen/qwen3-embedding-8b` — 4096 dimensions)
> **TTS** : OpenRouter (`hexgrad/kokoro-82m`, voix `ff_siwis`)
> **STT** : OpenRouter (`openai/whisper-large-v3-turbo`)
> **Jobs** : Solid Queue (plugin Puma, single dyno Basic $7/mois)
> **Hébergement** : Heroku Basic ($7) + Postgres Essential-0 ($5) = **$12/mois**
> **Budget crédits étudiants** : $13/mois → marge $1 pour APIs

---

## Table des matières

1. [Architecture cible](#architecture-cible)
2. [Prérequis](#prérequis)
3. [Phase 1 — Fondations (pgvector + Chat UI)](#phase-1--fondations-pgvector--chat-ui)
4. [Phase 2 — RAG (le cœur)](#phase-2--rag-le-cœur)
5. [Phase 3 — Scraping + Enrichissement](#phase-3--scraping--enrichissement)
6. [Phase 4 — Chat contextuel + Recherche sémantique](#phase-4--chat-contextuel--recherche-sémantique)
7. [Phase 5 — Voice (STT/TTS) + Déploiement](#phase-5--voice-stttts--déploiement)
8. [Récapitulatif — Tous les fichiers](#récapitulatif--tous-les-fichiers)

---

## Architecture cible

```
Heroku Basic dyno ($7/mois) ─ toujours allumé, 512 MB RAM
┌─────────────────────────────────────────────────┐
│  Puma + Solid Queue (plugin Puma, même process)  │
│                                                   │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │Controllers│  │  Jobs    │  │  Services     │  │
│  │           │  │          │  │               │  │
│  │ Messages  │  │ EmbedDoc │  │ RagService    │  │
│  │ TTS / STT │  │ ScrapeLk │  │ ChunkingSvc   │  │
│  │ Search    │  │ Summarize│  │ EmbeddingSvc  │  │
│  │ FolderChat│  │ TagDoc   │  │ ScrapingSvc   │  │
│  └──────────┘  │ SynthSpch│  │ LlmTools      │  │
│                 └──────────┘  └───────────────┘  │
│                       │                           │
└───────────────────────┼───────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
   ┌─────────┐   ┌──────────┐   ┌─────────────┐
   │ PG      │   │ OpenRouter│   │ Cloudinary  │
   │ +vector │   │ LLM/Emb  │   │ fichiers    │
   │ $5/mois │   │ TTS/STT   │   │ gratuit tier│
   │ 1 GB    │   │           │   │             │
   └─────────┘   └──────────┘   └─────────────┘
```

### Graphe de dépendances entre phases

```
Phase 1 ──► Phase 2 ──► Phase 3
(fondations)  (RAG)     (scraping+enrich)
                   │          │
                   ▼          ▼
                Phase 4 ◄─────┘
                (chat contextuel + recherche)

Phase 1 ──► Phase 5
              (voice + déploiement)
```

Phase 5 peut démarrer **dès que Phase 1 est terminée** (chat UI fonctionnel).

---

## Prérequis

À faire avant toute phase.

### Gems à ajouter

```ruby
# Gemfile
gem "neighbor"               # pgvector pour ActiveRecord
gem "mission_control-jobs"   # Dashboard Solid Queue
gem "tokenizers"             # Comptage tokens précis pour chunking (optionnel)
```

```bash
bundle install
```

### Variables d'environnement

```bash
# .env (développement)
OPENROUTER_API_KEY=sk-or-v1-...
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
CLOUDINARY_URL=cloudinary://...
```

### Configuration RubyLLM → OpenRouter

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_base = ENV["OPENROUTER_BASE_URL"]
  config.openai_api_key = ENV["OPENROUTER_API_KEY"]
end
```

### Mission Control Jobs

```ruby
# config/routes.rb — ajout en dev
mount MissionControl::Jobs::Engine, at: "/jobs" if Rails.env.development?
```

---

## Phase 1 — Fondations (pgvector + Chat UI)

**Objectif** : Activer pgvector, créer la table de chunks + embeddings, corriger l'UI du chat.
**Durée estimée** : 3-4h
**Dépendances** : Aucune
**Valeur livrée** : Le chat fonctionne visuellement + l'infra vectorielle est en place.

### 1.1 Migration pgvector + table document_chunks

```ruby
# db/migrate/XXXX_enable_pgvector.rb
class EnablePgvector < ActiveRecord::Migration[8.1]
  def change
    enable_extension "vector"
  end
end
```

```ruby
# db/migrate/XXXX_create_document_chunks.rb
class CreateDocumentChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :document_chunks do |t|
      t.references :document, null: false, foreign_key: { on_delete: :cascade }
      t.integer :chunk_index, null: false
      t.text :content, null: false
      t.integer :token_count
      t.column :embedding, :vector, limit: 4096
      t.timestamps
    end

    add_index :document_chunks, :embedding,
      using: :hnsw,
      opclass: :vector_cosine_ops,
      name: "idx_document_chunks_embedding"
  end
end
```

```ruby
# db/migrate/XXXX_add_status_to_documents.rb
class AddStatusToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :embedding_status, :string, default: "pending"
    add_column :documents, :summary, :text
    add_column :documents, :source_url, :string
  end
end
```

### 1.2 Modèle DocumentChunk

```ruby
# app/models/document_chunk.rb
class DocumentChunk < ApplicationRecord
  belongs_to :document
  has_neighbors :embedding
end
```

### 1.3 Service de chunking

```ruby
# app/services/chunking_service.rb
class ChunkingService
  CHUNK_SIZE = 512        # tokens cibles par chunk
  CHUNK_OVERLAP = 64      # chevauchement entre chunks

  def initialize(text)
    @text = text
  end

  def call
    paragraphs = @text.split(/\n{2,}/)
    chunks = []
    current = ""

    paragraphs.each do |para|
      if token_count(current + " " + para) > CHUNK_SIZE
        chunks << current.strip unless current.empty?
        current = overlap_from(current) + "\n\n" + para
      else
        current += "\n\n" + para
      end
    end
    chunks << current.strip unless current.empty?
    chunks
  end

  private

  def token_count(text)
    text.length / 4  # estimation: 1 token ≈ 4 caractères
  end

  def overlap_from(text)
    sentences = text.split(/(?<=[.!?])\s+/)
    overlap = ""
    sentences.reverse_each do |s|
      break if token_count(overlap + s) > CHUNK_OVERLAP
      overlap = s + " " + overlap
    end
    overlap.strip
  end
end
```

### 1.4 Service d'embedding

```ruby
# app/services/embedding_service.rb
class EmbeddingService
  def self.embed(text)
    uri = URI("#{ENV['OPENROUTER_BASE_URL']}/embeddings")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{ENV['OPENROUTER_API_KEY']}"
    request["Content-Type"] = "application/json"
    request.body = {
      model: "qwen/qwen3-embedding-8b",
      input: text
    }.to_json

    response = http.request(request)
    JSON.parse(response.body).dig("data", 0, "embedding")
  end
end
```

### 1.5 Job d'embedding

```ruby
# app/jobs/embed_document_job.rb
class EmbedDocumentJob < ApplicationJob
  queue_as :ai

  def perform(document_id)
    document = Document.find(document_id)
    return if document.content.blank?

    document.update!(embedding_status: "processing")

    # Supprimer les anciens chunks
    document.document_chunks.destroy_all

    # Découper puis embedder chaque chunk
    chunks = ChunkingService.new(document.content).call
    chunks.each_with_index do |content, idx|
      embedding = EmbeddingService.embed(content)
      document.document_chunks.create!(
        chunk_index: idx,
        content: content,
        token_count: content.length / 4,
        embedding: embedding
      )
    end

    document.update!(embedding_status: "completed")

    # Chaînage — Phases 3+
    SummarizeDocumentJob.perform_later(document_id)
    TagDocumentJob.perform_later(document_id)
  rescue StandardError => e
    document.update!(embedding_status: "failed")
    Rails.logger.error "EmbedDocumentJob échec doc #{document_id}: #{e.message}"
  end
end
```

### 1.6 Trigger sur Document

```ruby
# app/models/document.rb — ajouts
has_many :document_chunks, dependent: :destroy

after_commit :embed_async, on: [:create, :update]

private

def embed_async
  return if content.blank?
  EmbedDocumentJob.perform_later(id)
end
```

### 1.7 UI Chat — partial manquant

```erb
<!-- app/views/messages/_message.html.erb -->
<div class="message <%= message.role == 'user' ? 'message--user' : 'message--assistant' %> mb-3"
     data-role="<%= message.role %>">
  <div class="d-flex align-items-start gap-2">
    <div class="message__avatar pt-1">
      <% if message.role == "user" %>
        <i class="fa-solid fa-user text-teal"></i>
      <% else %>
        <i class="fa-solid fa-robot text-teal"></i>
      <% end %>
    </div>
    <div class="message__body flex-grow-1">
      <div class="message__text">
        <%= simple_format(message.content) %>
      </div>
      <div class="d-flex align-items-center gap-2 mt-1">
        <small class="text-muted"><%= time_ago_in_words(message.created_at) %></small>
        <% if message.role == "assistant" %>
          <button type="button"
                  data-action="click->voice#speak"
                  data-voice-text-param="<%= message.content %>"
                  class="btn btn-sm btn-link p-0"
                  aria-label="Lire la réponse à voix haute">
            <i class="fa-solid fa-volume-high"></i>
          </button>
        <% end %>
      </div>
    </div>
  </div>
</div>
```

```erb
<!-- app/views/messages/create.turbo_stream.erb -->
<%= turbo_stream.append "messages" do %>
  <%= render @user_message %>
  <%= render @ai_message %>
<% end %>

<%= turbo_stream.replace "new_message_form" do %>
  <%= render "messages/form", conversation: @conversation, message: Message.new %>
<% end %>
```

```erb
<!-- app/views/messages/_form.html.erb (extraire le form de show) -->
<%= simple_form_for [conversation, message],
      html: {
        data: {
          controller: "voice",
          action: "turbo:submit-end->voice#clearInput"
        }
      } do |f| %>
  <div class="input-group">
    <%= f.input :content,
          label: false,
          placeholder: "Écris ton message...",
          input_html: {
            data: { voice_target: "input" },
            rows: 2,
            class: "form-control",
            autofocus: true
          } %>
    <button type="button"
            data-action="voice#startRecording"
            class="btn btn-outline-secondary"
            aria-label="Dicter un message">
      <i class="fa-solid fa-microphone"></i>
    </button>
    <%= f.button :submit, "Envoyer", class: "btn btn-primary" %>
  </div>
<% end %>
```

### 1.8 Correction conversations/show.html.erb

```erb
<!-- app/views/conversations/show.html.erb -->
<main class="d-flex flex-column" style="min-height: calc(100vh - 70px); padding-top: 70px;">
  <!-- Zone messages scrollable -->
  <div class="flex-grow-1 overflow-auto px-3 py-4"
       style="max-width: 800px; margin: 0 auto; width: 100%;">
    <div id="messages" role="log" aria-label="Historique des messages" aria-live="polite">
      <% if @messages&.any? %>
        <%= render @messages %>
      <% else %>
        <div class="text-center text-muted py-5">
          <i class="fa-solid fa-comments fa-3x mb-3 d-block"></i>
          <p>Pose ta première question à MindSnap.</p>
          <p class="small">L'IA répond en s'appuyant sur tes documents.</p>
        </div>
      <% end %>
    </div>
  </div>

  <!-- Barre de saisie fixée en bas -->
  <div class="border-top bg-white p-3">
    <div style="max-width: 800px; margin: 0 auto;">
      <%= turbo_frame_tag "new_message_form" do %>
        <%= render "messages/form", conversation: @conversation, message: Message.new %>
      <% end %>
    </div>
  </div>
</main>
```

### Phase 1 — Checklist

- [ ] Migration `enable_extension "vector"`
- [ ] Migration `create_document_chunks` (HNSW index)
- [ ] Migration `add_status_to_documents`
- [ ] Modèle `DocumentChunk` + `has_neighbors`
- [ ] `ChunkingService` avec split par paragraphes + overlap
- [ ] `EmbeddingService` appel OpenRouter `qwen3-embedding-8b`
- [ ] `EmbedDocumentJob` (Solid Queue, queue `:ai`)
- [ ] `after_commit :embed_async` sur Document
- [ ] `app/views/messages/_message.html.erb`
- [ ] `app/views/messages/_form.html.erb`
- [ ] `app/views/messages/create.turbo_stream.erb`
- [ ] Correction `conversations/show.html.erb`
- [ ] `rails db:migrate` passe
- [ ] `rails test` passe (vérifier non-régression)

---

## Phase 2 — RAG (le cœur)

**Objectif** : L'IA répond en s'appuyant sur les documents de l'utilisateur via recherche vectorielle.
**Durée estimée** : 3-4h
**Dépendances** : Phase 1 (pgvector + embeddings)
**Valeur livrée** : L'IA cite les vrais documents de l'utilisateur. C'est LE killer feature.

### 2.1 RagService

```ruby
# app/services/rag_service.rb
class RagService
  def initialize(user)
    @user = user
  end

  # Recherche les chunks les plus pertinents
  # @param query [String] la question de l'utilisateur
  # @param folder_id [Integer, nil] scope optionnel à un dossier
  # @param limit [Integer] nombre de chunks à retourner
  def search(query, folder_id: nil, limit: 5)
    query_embedding = EmbeddingService.embed(query)

    scope = DocumentChunk
      .joins(:document)
      .where(documents: { user_id: @user.id })

    scope = scope.where(documents: { folder_id: folder_id }) if folder_id

    scope
      .nearest_neighbors(:embedding, query_embedding)
      .limit(limit)
      .includes(:document)
  end

  # Formate les chunks en contexte lisible pour le LLM
  def format_context(chunks)
    return nil if chunks.empty?

    chunks.group_by(&:document).map do |document, doc_chunks|
      <<~CONTEXT
        [Document: "#{document.title}" — Type: #{document.document_type}]
        #{doc_chunks.map(&:content).join("\n---\n")}
      CONTEXT
    end.join("\n\n")
  end
end
```

### 2.2 MessagesController — RAG intégré

```ruby
# app/controllers/messages_controller.rb — méthode call_llm modifiée

def call_llm
  # 1. Recherche RAG
  rag = RagService.new(current_user)
  folder_id = @conversation.context_id if @conversation.context_type == "Folder"
  chunks = rag.search(@user_message.content, folder_id: folder_id, limit: 5)
  context = rag.format_context(chunks)

  # 2. Appel LLM avec contexte
  llm = RubyLLM.chat(model: @conversation.model || "deepseek/deepseek-v4-flash")
  llm.with_instructions(build_system_prompt(context))

  # 3. Injecter l'historique de conversation (max 15 derniers messages)
  previous = @conversation.messages
    .where(role: %w[user assistant])
    .where.not(id: @user_message.id)
    .order(:created_at)
    .last(15)
  previous.each { |m| llm.add_message(role: m.role.to_sym, content: m.content) }

  llm.ask(@user_message.content).content
end

def build_system_prompt(context)
  <<~PROMPT
    Tu es MindSnap, un assistant de gestion de connaissances personnelles.
    Tu aides l'utilisateur à retrouver, comprendre et connecter ses documents.

    ## Contexte documentaire
    #{context.presence || "Aucun document pertinent trouvé dans la base de l'utilisateur."}

    ## Règles strictes
    1. Si des documents pertinents sont fournis ci-dessus → base ta réponse dessus et cite le titre du document comme source : *(source: Titre du doc)*
    2. Si aucun document pertinent → dis "Je n'ai rien trouvé dans tes documents à ce sujet, mais voici ce que je sais :" puis réponds avec tes connaissances générales
    3. Ne mélange JAMAIS tes connaissances générales avec le contenu spécifique des documents
    4. Sois concis, structuré, et réponds dans la même langue que la question
    5. Si la question ne concerne pas les documents, réponds normalement sans chercher à tout prix une source
  PROMPT
end
```

### 2.3 Test manuel RAG

```bash
bin/rails c

# Créer un document de test
doc = User.first.documents.create!(
  title: "Introduction au ML",
  content: "Le machine learning est une branche de l'intelligence artificielle qui permet aux ordinateurs d'apprendre sans être explicitement programmés. Les algorithmes de ML s'améliorent avec l'expérience.",
  document_type: "Note"
)

# Vérifier que l'embedding est fait
doc.reload.embedding_status
# => "completed" (après exécution du job)
doc.document_chunks.count
# => 1 (ou plus selon taille)

# Tester la recherche RAG
rag = RagService.new(User.first)
chunks = rag.search("c'est quoi le machine learning ?")

chunks.map { |c| c.document.title }
# => ["Introduction au ML"]
```

### Phase 2 — Checklist

- [ ] `RagService` avec `search` (vector cosine) et `format_context`
- [ ] `MessagesController#call_llm` modifié → appel RAG avant LLM
- [ ] `MessagesController#build_system_prompt` avec contexte documentaire
- [ ] Scope folder dans RagService (préparé pour Phase 4)
- [ ] Test manuel : créer doc → poser question → réponse cite le document
- [ ] Gestion cas "aucun document trouvé"

---

## Phase 3 — Scraping + Enrichissement

**Objectif** : Documents de type "Lien" scrapés automatiquement via Scrapling. Chaque document reçoit un résumé IA + des tags auto-générés.
**Durée estimée** : 4-5h
**Dépendances** : Phase 1 (embeddings), Phase 2 (RagService pour structure)
**Valeur livrée** : Un lien devient un doc recherchable. Chaque doc enrichi de résumé + tags.

### 3.1 Migration tags

```ruby
# db/migrate/XXXX_create_tags.rb
class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.string :name, null: false, limit: 50
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :tags, [:name, :user_id], unique: true

    create_table :taggings do |t|
      t.references :tag, null: false, foreign_key: { on_delete: :cascade }
      t.references :taggable, polymorphic: true, null: false
      t.timestamps
    end
    add_index :taggings, [:tag_id, :taggable_type, :taggable_id],
      unique: true,
      name: "idx_taggings_unique"
  end
end
```

```ruby
# db/migrate/XXXX_add_scraping_status_to_documents.rb
class AddScrapingStatusToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :scraping_status, :string
    # valeurs: nil / "scraping" / "scraped" / "failed"
  end
end
```

### 3.2 Modèles Tag / Tagging

```ruby
# app/models/tag.rb
class Tag < ApplicationRecord
  belongs_to :user
  has_many :taggings, dependent: :destroy

  validates :name, presence: true,
            uniqueness: { scope: :user_id, case_sensitive: false }

  before_save { self.name = name.downcase.strip }
end
```

```ruby
# app/models/tagging.rb
class Tagging < ApplicationRecord
  belongs_to :tag
  belongs_to :taggable, polymorphic: true
end
```

```ruby
# app/models/document.rb — ajouts
has_many :taggings, as: :taggable, dependent: :destroy
has_many :tags, through: :taggings

after_commit :scrape_async, on: :create

def scrape_async
  return unless document_type == "Lien" && source_url.present? && content.blank?
  ScrapeLinkJob.perform_later(id)
end
```

### 3.3 Job scraping lien

```ruby
# app/jobs/scrape_link_job.rb
class ScrapeLinkJob < ApplicationJob
  queue_as :ai

  def perform(document_id)
    document = Document.find(document_id)
    return unless document.document_type == "Lien"
    return if document.source_url.blank?

    document.update!(scraping_status: "scraping")

    content = ScrapingService.fetch(document.source_url)

    if content.present?
      document.update!(
        content: content,
        scraping_status: "scraped"
      )
      EmbedDocumentJob.perform_later(document_id)
    else
      document.update!(scraping_status: "failed")
    end
  rescue StandardError => e
    document.update!(scraping_status: "failed")
    Rails.logger.error "ScrapeLinkJob échec doc #{document_id}: #{e.message}"
  end
end
```

### 3.4 Service scraping

```ruby
# app/services/scraping_service.rb
require "net/http"
require "nokogiri"

class ScrapingService
  MAX_CONTENT_LENGTH = 50_000

  def self.fetch(url)
    uri = URI(url)
    return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    response = Net::HTTP.get_response(uri)
    return nil unless response.is_a?(Net::HTTPSuccess)

    doc = Nokogiri::HTML(response.body)
    doc.css("script, style, nav, footer, header, aside, noscript").remove
    doc.css("body").text.gsub(/\s+/, " ").strip.truncate(MAX_CONTENT_LENGTH)
  rescue StandardError => e
    Rails.logger.error "ScrapingService échec pour #{url}: #{e.message}"
    nil
  end
end
```

### 3.5 Job résumé

```ruby
# app/jobs/summarize_document_job.rb
class SummarizeDocumentJob < ApplicationJob
  queue_as :ai

  def perform(document_id)
    document = Document.find(document_id)
    return if document.content.blank?

    llm = RubyLLM.chat(model: "deepseek/deepseek-v4-flash")
    summary = llm.ask(build_prompt(document.content)).content

    document.update!(summary: summary&.strip)
  rescue StandardError => e
    Rails.logger.error "SummarizeDocumentJob échec doc #{document_id}: #{e.message}"
  end

  private

  def build_prompt(content)
    <<~PROMPT
      Résume le document suivant en 3 phrases maximum.
      Sois concis et factuel. Ne commence pas par "Ce document..."
      ou "L'auteur...". Va directement au contenu essentiel.

      Document :
      #{content.truncate(4000)}
    PROMPT
  end
end
```

### 3.6 Job tags

```ruby
# app/jobs/tag_document_job.rb
class TagDocumentJob < ApplicationJob
  queue_as :ai

  MAX_TAGS = 5

  def perform(document_id)
    document = Document.find(document_id)
    return if document.content.blank?

    llm = RubyLLM.chat(model: "deepseek/deepseek-v4-flash")
    response = llm.ask(build_prompt(document.content)).content

    tag_names = response
      .split(",")
      .map(&:strip)
      .map(&:downcase)
      .select(&:present?)
      .first(MAX_TAGS)

    tag_names.each do |name|
      tag = document.user.tags.find_or_create_by!(name: name)
      Tagging.find_or_create_by!(tag: tag, taggable: document)
    end
  rescue StandardError => e
    Rails.logger.error "TagDocumentJob échec doc #{document_id}: #{e.message}"
  end

  private

  def build_prompt(content)
    <<~PROMPT
      Suggère 3 à 5 mots-clés (tags) pour le document ci-dessous.
      Format de réponse : mot1, mot2, mot3
      Règles : minuscules, 1 à 3 mots maximum par tag, séparés par des virgules.

      Document :
      #{content.truncate(3000)}
    PROMPT
  end
end
```

### 3.7 Chaînage dans EmbedDocumentJob

Déjà fait dans le code de Phase 1 — les jobs `SummarizeDocumentJob` et `TagDocumentJob` sont appelés à la fin de `EmbedDocumentJob#perform`.

### 3.8 UI — résumé + tags dans les cartes document

```erb
<!-- app/views/shared/_document_card.html.erb — ajouts dans la carte existante -->

<!-- Afficher le résumé si présent -->
<% if document.summary.present? %>
  <p class="document-card__summary text-muted small mb-2">
    <%= document.summary %>
  </p>
<% end %>

<!-- Afficher les tags -->
<% if document.tags.any? %>
  <div class="document-card__tags mt-2">
    <% document.tags.each do |tag| %>
      <span class="badge bg-light text-dark me-1"><%= tag.name %></span>
    <% end %>
  </div>
<% end %>

<!-- Badge statut lien -->
<% if document.document_type == "Lien" && document.scraping_status.present? %>
  <% case document.scraping_status %>
  <% when "scraping" %>
    <span class="badge bg-warning text-dark">Scraping en cours...</span>
  <% when "scraped" %>
    <span class="badge bg-success">Contenu extrait</span>
  <% when "failed" %>
    <span class="badge bg-danger">Échec extraction</span>
  <% end %>
<% end %>
```

### Phase 3 — Checklist

- [ ] Migration `create_tags` + `create_taggings`
- [ ] Migration `add_scraping_status_to_documents`
- [ ] Modèles `Tag` + `Tagging` + relations sur Document
- [ ] `ScrapingService.fetch(url)` avec Nokogiri
- [ ] `ScrapeLinkJob` + trigger `after_commit :scrape_async`
- [ ] `SummarizeDocumentJob` avec prompt 3 phrases
- [ ] `TagDocumentJob` avec prompt mots-clés
- [ ] Chaînage dans `EmbedDocumentJob` (déjà codé en Phase 1)
- [ ] UI: résumé + tags + badge scraping dans `_document_card.html.erb`
- [ ] Test: créer un doc Lien avec URL → vérifier scraping → vérifier résumé/tags

---

## Phase 4 — Chat contextuel + Recherche sémantique

**Objectif** : Chatter avec un dossier spécifique. Page de recherche sémantique unifiée.
**Durée estimée** : 4-5h
**Dépendances** : Phase 2 (RagService)
**Valeur livrée** : Conversations scopées par dossier + moteur de recherche intelligent.

### 4.1 Migration — contexte polymorphic sur conversations

```ruby
# db/migrate/XXXX_add_context_to_conversations.rb
class AddContextToConversations < ActiveRecord::Migration[8.1]
  def change
    add_column :conversations, :context_type, :string
    add_column :conversations, :context_id, :bigint
    add_column :conversations, :model, :string,
      default: "deepseek/deepseek-v4-flash"

    add_index :conversations, [:context_type, :context_id]
  end
end
```

### 4.2 Modèle Conversation

```ruby
# app/models/conversation.rb — ajouts
belongs_to :context, polymorphic: true, optional: true

def folder_scoped?
  context_type == "Folder" && context_id.present?
end
```

### 4.3 Routes

```ruby
# config/routes.rb — ajouts

resources :folders do
  post :chat, on: :member
end

get "search", to: "searches#index"
```

### 4.4 Chat avec un dossier

```ruby
# app/controllers/folders_controller.rb — ajout

def chat
  @folder = current_user.folders.find(params[:id])
  @conversation = current_user.conversations.create!(
    name: "#{@folder.name}",
    context: @folder
  )
  redirect_to conversation_path(@conversation)
end
```

```erb
<!-- app/views/folders/show.html.erb — ajout d'un bouton -->
<div class="mb-4">
  <%= button_to chat_folder_path(@folder),
        method: :post,
        class: "btn btn-primary",
        data: { turbo: false } do %>
    <i class="fa-solid fa-robot me-1"></i> Discuter avec ce dossier
  <% end %>
  <p class="text-muted small mt-1">
    L'IA cherchera uniquement dans les documents de ce dossier.
  </p>
</div>
```

### 4.5 MessagesController — adaptation scope folder

```ruby
# app/controllers/messages_controller.rb — call_llm déjà géré en Phase 2
# La détection du folder_id est intégrée dans call_llm :

folder_id = @conversation.context_id if @conversation.context_type == "Folder"
chunks = rag.search(@user_message.content, folder_id: folder_id, limit: 5)
```

### 4.6 Recherche sémantique unifiée

```ruby
# app/controllers/searches_controller.rb
class SearchesController < ApplicationController
  def index
    @query = params[:q]

    if @query.present?
      rag = RagService.new(current_user)
      @chunks = rag.search(@query, limit: 20)
      @documents = Document
        .where(id: @chunks.map(&:document_id).uniq)
        .includes(:tags, :folder)
    end
  end
end
```

```erb
<!-- app/views/searches/index.html.erb -->
<% content_for :title, "Recherche — MindSnap" %>

<main class="container py-5" style="max-width: 800px;">
  <h1 class="mb-4">Recherche intelligente</h1>

  <%= form_tag search_path, method: :get, class: "mb-5" do %>
    <div class="input-group input-group-lg">
      <%= text_field_tag :q, @query,
            class: "form-control",
            placeholder: "Recherche par sens, pas par mots-clés...",
            autofocus: true,
            autocomplete: "off" %>
      <button class="btn btn-primary" type="submit" aria-label="Rechercher">
        <i class="fa-solid fa-magnifying-glass"></i>
      </button>
    </div>
    <p class="text-muted small mt-2">
      La recherche sémantique comprend le sens de ta question, pas juste les mots.
    </p>
  <% end %>

  <% if @query.present? %>
    <% if @documents&.any? %>
      <p class="text-muted mb-4">
        <%= @documents.count %> document(s) trouvé(s)
        pour « <%= @query %> »
      </p>
      <div class="row g-4">
        <% @documents.each do |document| %>
          <div class="col-12">
            <%= render "shared/document_card", document: document %>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="text-center py-5">
        <i class="fa-solid fa-file-circle-question fa-3x text-muted mb-3 d-block"></i>
        <p class="mb-1">Aucun document trouvé pour « <%= @query %> ».</p>
        <p class="text-muted small">
          Essaie avec d'autres mots ou crée un nouveau document.
        </p>
        <%= link_to "Créer un document", new_document_path, class: "btn btn-primary mt-3" %>
      </div>
    <% end %>
  <% else %>
    <div class="text-center py-5 text-muted">
      <i class="fa-solid fa-search fa-3x mb-3 d-block"></i>
      <p>Entre un mot-clé ou une phrase pour rechercher dans tous tes documents.</p>
    </div>
  <% end %>
</main>
```

### 4.7 Navbar — lien recherche

```erb
<!-- app/views/shared/_navbar.html.erb — ajout dans la liste de liens -->
<li class="nav-item">
  <%= link_to search_path, class: "nav-link" do %>
    <i class="fa-solid fa-magnifying-glass me-1"></i> Recherche
  <% end %>
</li>
```

### Phase 4 — Checklist

- [ ] Migration `add_context_to_conversations`
- [ ] Relation `belongs_to :context, polymorphic: true` sur Conversation
- [ ] Routes : `POST /folders/:id/chat`, `GET /search`
- [ ] `FoldersController#chat`
- [ ] Bouton "Discuter avec ce dossier" dans `folders/show`
- [ ] `SearchesController#index` + vue `searches/index`
- [ ] Lien recherche dans la navbar
- [ ] Test: chat dossier → réponse ne cite que les docs du dossier
- [ ] Test: recherche → taper phrase → résultats pertinents

---

## Phase 5 — Voice (STT/TTS) + Déploiement

**Objectif** : Chat vocal complet. Déploiement Heroku production.
**Durée estimée** : 4-5h
**Dépendances** : Phase 1 (chat UI fonctionnel)
**Valeur livrée** : On peut dicter un message et écouter la réponse. App en production.

### 5.1 Routes voice

```ruby
# config/routes.rb — ajouts
post "tts/speak", to: "tts#speak"
post "transcribe", to: "transcriptions#create"
```

### 5.2 Contrôleur TTS

```ruby
# app/controllers/tts_controller.rb
class TtsController < ApplicationController
  MAX_TEXT_LENGTH = 4000

  def speak
    text = params[:text].to_s.strip
    voice = params[:voice] || "ff_siwis"

    return head :bad_request if text.blank?
    return head :bad_request if text.length > MAX_TEXT_LENGTH

    uri = URI("#{ENV['OPENROUTER_BASE_URL']}/audio/speech")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{ENV['OPENROUTER_API_KEY']}"
    request["Content-Type"] = "application/json"
    request.body = {
      model: "hexgrad/kokoro-82m",
      input: text,
      voice: voice,
      response_format: "mp3"
    }.to_json

    response = http.request(request)

    if response.code.to_i == 200
      send_data response.body,
        type: "audio/mpeg",
        disposition: "inline"
    else
      Rails.logger.error "TTS failed: #{response.code} — #{response.body}"
      head :unprocessable_entity
    end
  end
end
```

### 5.3 Contrôleur STT

```ruby
# app/controllers/transcriptions_controller.rb
class TranscriptionsController < ApplicationController
  MAX_AUDIO_SIZE = 10 * 1024 * 1024 # 10 MB

  def create
    audio_base64 = params[:audio_base64]
    format = params[:format] || "webm"
    language = params[:language] || "fr"

    return head :bad_request if audio_base64.blank?

    # Vérification taille approximative (base64)
    estimated_size = (audio_base64.length * 3) / 4
    return head :payload_too_large if estimated_size > MAX_AUDIO_SIZE

    uri = URI("#{ENV['OPENROUTER_BASE_URL']}/audio/transcriptions")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{ENV['OPENROUTER_API_KEY']}"
    request["Content-Type"] = "application/json"
    request.body = {
      model: "openai/whisper-large-v3-turbo",
      input_audio: {
        data: audio_base64,
        format: format
      },
      language: language
    }.to_json

    response = http.request(request)

    if response.code.to_i == 200
      render json: JSON.parse(response.body)
    else
      Rails.logger.error "Transcription failed: #{response.code} — #{response.body}"
      render json: { error: "Transcription failed" }, status: :unprocessable_entity
    end
  end
end
```

### 5.4 Stimulus voice controller

```javascript
// app/javascript/controllers/voice_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.isRecording = false
  }

  async startRecording() {
    if (this.isRecording) return

    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      alert("L'accès au microphone n'est pas supporté par ton navigateur.")
      return
    }

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      this.isRecording = true

      const mimeType = MediaRecorder.isTypeSupported("audio/webm;codecs=opus")
        ? "audio/webm;codecs=opus"
        : "audio/webm"

      this.mediaRecorder = new MediaRecorder(stream, { mimeType })
      const chunks = []

      this.mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) chunks.push(e.data)
      }

      this.mediaRecorder.onstop = async () => {
        this.isRecording = false
        stream.getTracks().forEach((t) => t.stop())

        if (chunks.length === 0) return

        const blob = new Blob(chunks, { type: mimeType })
        const base64 = await this.blobToBase64(blob)
        const text = await this.transcribe(base64)

        if (text && this.hasInputTarget) {
          this.inputTarget.value = text
          this.inputTarget.form.requestSubmit()
        }
      }

      this.mediaRecorder.start()
      setTimeout(() => {
        if (this.mediaRecorder?.state === "recording") {
          this.mediaRecorder.stop()
        }
      }, 30000) // max 30 secondes
    } catch (err) {
      this.isRecording = false
      console.error("Erreur microphone:", err)
      alert("Impossible d'accéder au microphone. Vérifie les permissions.")
    }
  }

  async speak({ params: { text } }) {
    if (!text) return

    try {
      const response = await fetch("/tts/speak", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text, voice: "ff_siwis" })
      })

      if (!response.ok) {
        console.error("TTS failed:", response.status)
        return
      }

      const blob = await response.blob()
      const audio = new Audio(URL.createObjectURL(blob))
      await audio.play()
    } catch (err) {
      console.error("Erreur TTS:", err)
    }
  }

  clearInput() {
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
    }
  }

  // Privé
  blobToBase64(blob) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.onloadend = () => resolve(reader.result.split(",")[1])
      reader.onerror = reject
      reader.readAsDataURL(blob)
    })
  }

  async transcribe(base64) {
    try {
      const response = await fetch("/transcribe", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          audio_base64: base64,
          format: "webm",
          language: "fr"
        })
      })

      if (!response.ok) {
        console.error("Transcription failed:", response.status)
        return null
      }

      const data = await response.json()
      return data.text || null
    } catch (err) {
      console.error("Erreur transcription:", err)
      return null
    }
  }
}
```

### 5.5 Déploiement Heroku

```procfile
# Procfile
web: bundle exec rails server -p $PORT
```

```ruby
# config/puma.rb — ajout en fin de fichier
plugin :solid_queue
```

```yaml
# config/queue.yml — création si absent
production:
  workers:
    - queues: [ default, ai, mailers ]
      threads: 2
      polling_interval: 2
```

```yaml
# config/storage.yml — ajout production
production:
  service: Cloudinary
```

```ruby
# config/environments/production.rb — vérifier
config.active_storage.service = :cloudinary
config.action_mailer.default_url_options = { host: "mindsnap.herokuapp.com" }
config.force_ssl = true
```

### Commandes de déploiement

```bash
# Créer l'app
heroku create mindsnap --region eu

# Addons
heroku addons:create heroku-postgresql:essential-0 --app mindsnap
# Cloudinary via addon ou variable d'env

# Variables d'environnement
heroku config:set OPENROUTER_API_KEY=sk-or-v1-... --app mindsnap
heroku config:set OPENROUTER_BASE_URL=https://openrouter.ai/api/v1 --app mindsnap
heroku config:set CLOUDINARY_URL=cloudinary://... --app mindsnap
heroku config:set RAILS_MASTER_KEY=$(cat config/credentials/production.key) --app mindsnap

# Déployer
git push heroku master

# Base de données
heroku run rails db:migrate --app mindsnap
heroku run rails db:schema:load --app mindsnap

# Activer pgvector (une seule fois)
heroku run rails runner \
  "ActiveRecord::Base.connection.execute('CREATE EXTENSION IF NOT EXISTS vector')" \
  --app mindsnap

# Ouvrir
heroku open --app mindsnap
```

### 5.6 Vérifications post-déploiement

```bash
# Vérifier que pgvector est bien activé
heroku run rails runner "puts ActiveRecord::Base.connection.execute('SELECT * FROM pg_extension WHERE extname = \'vector\'').to_a"

# Vérifier les jobs
heroku run rails runner "puts SolidQueue::Job.count"
heroku open /jobs  # Mission Control (si configuré en dev uniquement)
```

### Phase 5 — Checklist

- [ ] Routes `tts/speak` + `transcribe`
- [ ] `TtsController#speak` — proxy Kokoro → audio/mpeg
- [ ] `TranscriptionsController#create` — proxy Whisper → JSON { text }
- [ ] `voice_controller.js` Stimulus (enregistrement + lecture)
- [ ] Boutons micro + haut-parleur dans le chat (Phase 1 déjà codé)
- [ ] `Procfile` avec `web` uniquement (Solid Queue en plugin Puma)
- [ ] `config/puma.rb` → `plugin :solid_queue`
- [ ] `config/queue.yml` → config production
- [ ] `config/storage.yml` → Cloudinary production
- [ ] `config/environments/production.rb` → host, SSL
- [ ] Déploiement → `heroku create` + `git push heroku master`
- [ ] Activation pgvector → `CREATE EXTENSION IF NOT EXISTS vector`
- [ ] Test end-to-end : signup → créer doc → chat RAG → STT → TTS

---

## Récapitulatif — Tous les fichiers

### Nouveaux fichiers (23)

| # | Fichier | Phase |
|---|---------|:-----:|
| 1 | `db/migrate/*_enable_pgvector.rb` | 1 |
| 2 | `db/migrate/*_create_document_chunks.rb` | 1 |
| 3 | `db/migrate/*_add_status_to_documents.rb` | 1 |
| 4 | `db/migrate/*_create_tags.rb` | 3 |
| 5 | `db/migrate/*_add_scraping_status_to_documents.rb` | 3 |
| 6 | `db/migrate/*_add_context_to_conversations.rb` | 4 |
| 7 | `app/models/document_chunk.rb` | 1 |
| 8 | `app/models/tag.rb` | 3 |
| 9 | `app/models/tagging.rb` | 3 |
| 10 | `app/services/chunking_service.rb` | 1 |
| 11 | `app/services/embedding_service.rb` | 1 |
| 12 | `app/services/rag_service.rb` | 2 |
| 13 | `app/services/scraping_service.rb` | 3 |
| 14 | `app/jobs/embed_document_job.rb` | 1 |
| 15 | `app/jobs/scrape_link_job.rb` | 3 |
| 16 | `app/jobs/summarize_document_job.rb` | 3 |
| 17 | `app/jobs/tag_document_job.rb` | 3 |
| 18 | `app/controllers/searches_controller.rb` | 4 |
| 19 | `app/controllers/tts_controller.rb` | 5 |
| 20 | `app/controllers/transcriptions_controller.rb` | 5 |
| 21 | `app/views/messages/_message.html.erb` | 1 |
| 22 | `app/views/messages/_form.html.erb` | 1 |
| 23 | `app/views/messages/create.turbo_stream.erb` | 1 |
| 24 | `app/views/searches/index.html.erb` | 4 |
| 25 | `app/javascript/controllers/voice_controller.js` | 5 |
| 26 | `config/queue.yml` | 5 |
| 27 | `config/initializers/ruby_llm.rb` | Préreq |

### Fichiers modifiés (11)

| # | Fichier | Phase |
|---|---------|:-----:|
| 1 | `Gemfile` (+ neighbor, mission_control-jobs, tokenizers) | Préreq |
| 2 | `app/models/document.rb` (+ callbacks, relations chunks/tags) | 1, 3 |
| 3 | `app/models/conversation.rb` (+ context polymorphic, model) | 4 |
| 4 | `app/controllers/messages_controller.rb` (+ RAG, scope folder) | 2 |
| 5 | `app/controllers/folders_controller.rb` (+ action chat) | 4 |
| 6 | `app/views/conversations/show.html.erb` (refonte complète) | 1 |
| 7 | `app/views/folders/show.html.erb` (+ bouton chat) | 4 |
| 8 | `app/views/shared/_document_card.html.erb` (+ summary, tags, scraping) | 3 |
| 9 | `app/views/shared/_navbar.html.erb` (+ lien recherche) | 4 |
| 10 | `config/routes.rb` (+ search, tts, transcribe, folder chat) | 2, 4, 5 |
| 11 | `config/puma.rb` (+ plugin :solid_queue) | 5 |

---

## Notes

- **Les phases sont indépendantes** : Phase 5 peut démarrer après Phase 1. Phases 3-4 peuvent se faire en parallèle après Phase 2.
- **Coûts API estimés** : ~$1-2/mois pour usage étudiant (quelques centaines de messages + embeddings + TTS/STT). Rester sous les $13 de crédit Heroku.
- **Limite 1 GB disque Postgres** : surveiller la taille des embeddings (16 KB/vecteur → ~60K vecteurs max). Pour la démo, c'est amplement suffisant.
- **Solid Queue plugin Puma** : les jobs tournent dans le même process que le serveur web. Pas idéal en production lourde mais parfait pour le budget contraint.
- **Améliorations futures** : reranker cross-encoder (quand budget dispo), chunking avec tokenizer précis, streaming LLM (Server-Sent Events), extension navigateur.
