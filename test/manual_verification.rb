# ============================================================
# Script de test manuel — Phase 1, 2, 3
# Lancer avec : bin/rails runner test/manual_verification.rb
# ============================================================

def banner(title)
  puts "\n#{'=' * 60}"
  puts "  #{title}"
  puts "#{'=' * 60}"
end

def ok(msg)
  puts "  ✅ #{msg}"
end

def fail(msg, error = nil)
  puts "  ❌ #{msg}"
  puts "     #{error.message}" if error
end

# -----------------------------------------------------------
# Préparation : utilisateur + assert utilisateur existant
# -----------------------------------------------------------
banner "PHASE 1 — Fondations (pgvector + embedding)"

user = User.first
if user.nil?
  fail "Aucun utilisateur. Crée un compte via l'interface."
  exit 1
end
ok "Utilisateur trouvé : #{user.email}"

# Test 1: Extension pgvector activée
result = ActiveRecord::Base.connection.execute(
  "SELECT extname FROM pg_extension WHERE extname = 'vector'"
)
if result.any?
  ok "Extension pgvector activée"
else
  fail "Extension pgvector PAS activée"
end

# Test 2: Créer un document et vérifier l'embedding
banner "Test 1.1 — Création document + embedding"
doc = user.documents.create!(
  title: "[TEST] Introduction au Machine Learning",
  content: "Le machine learning est une branche de l'intelligence artificielle. " * 5,
  document_type: "Note"
)
ok "Document créé : #{doc.title} (id=#{doc.id})"

if doc.embedding_status == "pending"
  ok "Embedding status = pending (le job va démarrer)"
else
  fail "Embedding status inattendu : #{doc.embedding_status}"
end

# Exécuter le job manuellement
banner "Test 1.2 — Exécution EmbedDocumentJob"
begin
  EmbedDocumentJob.perform_now(doc.id)
  doc.reload
  ok "EmbedDocumentJob exécuté"
  ok "Status: #{doc.embedding_status}"
  ok "Chunks créés: #{doc.document_chunks.count}"

  doc.document_chunks.each do |chunk|
    ok "Chunk #{chunk.chunk_index}: #{chunk.content.truncate(50)}... (#{chunk.token_count} tokens)"
    if chunk.embedding.present?
      ok "  → Embedding vector OK (#{chunk.embedding.length} dimensions)"
    else
      fail "  → Embedding VIDE"
    end
  end
rescue => e
  fail "EmbedDocumentJob a échoué", e
end

# Test 3: ChunkingService
banner "Test 1.3 — ChunkingService"
text = "Paragraphe un avec du contenu. Suite.\n\nParagraphe deux. Suite."
chunks = ChunkingService.new(text).call
if chunks.length >= 1
  ok "ChunkingService: #{chunks.length} chunk(s)"
else
  fail "ChunkingService: 0 chunks"
end

# Test 4: Embedded?
banner "Test 1.4 — Document#embedded?"
if doc.embedded?
  ok "Document#embedded? = true"
else
  fail "Document#embedded? devrait être true après embedding"
end

# -----------------------------------------------------------
# PHASE 2 — RAG
# -----------------------------------------------------------
banner "PHASE 2 — RAG (Recherche + Contexte)"

# Test 5: RagService.search
begin
  rag = RagService.new(user)
  results = rag.search("machine learning", limit: 3)
  if results.any?
    ok "RagService.search: #{results.length} résultats"
    results.each do |c|
      ok "  → #{c.document.title} (similarité via pgvector)"
    end
  else
    fail "RagService.search: 0 résultats"
  end
rescue => e
  fail "RagService.search a échoué", e
end

# Test 6: RagService.format_context
banner "Test 2.2 — format_context"
begin
  context = rag.format_context(results)
  if context.present?
    ok "format_context OK (#{context.length} caractères)"
    puts "  --- APERÇU ---"
    puts context.first(300)
    puts "  ..."
  else
    fail "format_context vide"
  end
rescue => e
  fail "format_context a échoué", e
end

# -----------------------------------------------------------
# PHASE 3 — Scraping + Enrichissement
# -----------------------------------------------------------
banner "PHASE 3 — Scraping + Résumé + Tags"

# Test 7: Tags
banner "Test 3.1 — Tags/Taggings"
begin
  tag = user.tags.create!(name: "  Test-TAG  ")
  ok "Tag créé et normalisé: '#{tag.name}'"

  tagging = Tagging.create!(tag: tag, taggable: doc)
  ok "Tagging créé: #{tag.name} → #{doc.title}"
  ok "Document a #{doc.tags.count} tag(s)"
rescue => e
  fail "Tags/Taggings a échoué", e
end

# Test 8: SummarizeDocumentJob
banner "Test 3.2 — SummarizeDocumentJob"
begin
  SummarizeDocumentJob.perform_now(doc.id)
  doc.reload
  if doc.summary.present?
    ok "Résumé généré: \"#{doc.summary.truncate(100)}\""
  else
    fail "Résumé VIDE (l'appel API a peut-être échoué)"
  end
rescue => e
  fail "SummarizeDocumentJob a échoué", e
end

# Test 9: TagDocumentJob
banner "Test 3.3 — TagDocumentJob"
begin
  # Nettoyer les tags manuels
  doc.taggings.destroy_all
  TagDocumentJob.perform_now(doc.id)
  doc.reload
  if doc.tags.any?
    ok "Tags auto-générés: #{doc.tags.pluck(:name).join(', ')}"
  else
    fail "Aucun tag généré (l'appel API a peut-être échoué)"
  end
rescue => e
  fail "TagDocumentJob a échoué", e
end

# Test 10: Scraping
banner "Test 3.4 — ScrapingService"
begin
  content = ScrapingService.fetch("https://example.com")
  if content.present?
    ok "Scraping de example.com OK (#{content.length} caractères)"
  else
    fail "Scraping a retourné nil (vérifie la connexion réseau)"
  end
rescue => e
  fail "ScrapingService a échoué", e
end

# -----------------------------------------------------------
# RÉSUMÉ
# -----------------------------------------------------------
banner "RÉSUMÉ"
puts ""
puts "  Document:     #{doc.title}"
puts "  Chunks:       #{doc.document_chunks.count}"
puts "  Embedding:    #{doc.embedded? ? '✅' : '❌'}"
puts "  Résumé:       #{doc.summary.present? ? '✅' : '❌'}"
puts "  Tags:         #{doc.tags.any? ? '✅' : '❌'} (#{doc.tags.pluck(:name).join(', ')})"
puts "  RAG search:   ✅ (#{rag.search('test', limit: 2).length} résultats)"
puts ""
puts "  Nettoie avec : Document.find(#{doc.id}).destroy"
puts ""
