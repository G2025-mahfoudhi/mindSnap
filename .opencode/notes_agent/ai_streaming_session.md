# Notes de session — Streaming IA token-par-token (2026-06-08)

> Session Luis + Claude Code — Implémentation du streaming SSE pour les
> réponses du chat IA dans MindSnap. Démarrage après le merge de la PR
> `discussion document précise` (Nabilah) qui a ajouté le scope Document.

---

## 🎯 Objectif de la session

Transformer le chat IA MindSnap de **synchrone** (réponse complète après
plusieurs secondes) en **streaming token-par-token** style ChatGPT.

L'utilisateur soumet un message → la bulle de l'IA apparaît immédiatement
vide avec un indicateur de chargement → le texte apparaît au fur et à
mesure que les tokens arrivent d'OpenRouter → indicateur disparaît à la
fin.

---

## 🏗️ Architecture cible (validée puis corrigée en cours de session)

### Pattern Rails/Hotwire canonique
1. User submit → `MessagesController#create` crée immédiatement :
   - `@user_message` (role: "user", content: <input>)
   - `@ai_message` (role: "assistant", content: **""**, **streaming: true**)
2. `StreamAiResponseJob.perform_later(@ai_message.id)` — job enqueue
3. Job appelle `OpenRouterService#call_streaming` qui yield chaque token
4. Job accumule les tokens par batch de 50ms (ou 80 chars), puis :
   - `update_columns(content: ...)` sur le message
   - `Turbo::StreamsChannel.broadcast_replace_to(@conversation, target: dom_id, partial: "messages/message")`
5. Côté client : `<%= turbo_stream_from @conversation %>` dans la vue →
   `Turbo::StreamsChannel` reçoit le broadcast → applique le replace
6. Le `chat_scroll_controller.js` détecte le `characterData` → scroll auto
7. À la fin du stream : `streaming: false` → bouton voice TTS apparaît

### Pourquoi `Turbo::StreamsChannel` (et pas un channel custom) ?

C'est **LA** leçon clé de cette session (cf. bug 1 plus bas).

- `turbo_stream_from @conversation` souscrit automatiquement au channel
  officiel `Turbo::StreamsChannel` (signe avec `Turbo::Streams::StreamName`)
- Tout broadcast via `Turbo::StreamsChannel.broadcast_*_to` est reçu et
  parsé nativement par Turbo (JS officiel, pas de code custom)
- Un channel ActionCable custom = double canal, JS custom à maintenir,
  format HTML manuel → fragile

---

## 📂 État du repo à l'ouverture de cette session

### Branche
`feature/ai-streaming` créée depuis `master` (HEAD = `9581f32`, après
le merge de la PR #74 "discussion document précise" de Nabilah).

### PR Nabilah mergée sur master (`3283eac`)
Nouveautés à intégrer dans le streaming :
- `OpenRouterService#system_prompt` : ajoute une section "Document en
  cours de discussion" quand la conversation est scopée à un Document
  (`@conversation.context_type == "Document"`)
- `OpenRouterService#build_rag_context` : passe `document_id:` à
  `RagService#search` quand scope Document
- `RagService#search` : nouveau param `document_id:` qui filtre au
  niveau du document avant de chercher les chunks
- `RagService#vector_search` : nouvelle condition
  `where(document_id: document_id) if document_id` (prioritaire sur
  `folder_id`)

⚠️ **Important** : cette PR ajoute un scope de conversation aux
Documents (pas juste aux Folders). Le streaming doit fonctionner
pour les 2 scopes (Folder ET Document).

### Conversations : 2 types
- **Chat principal** : `Conversation` sans `context` (nil) ou `context_type: "Folder"`
  → affiché sur `conversations/show.html.erb`
- **Doc-chat offcanvas** : `Conversation` avec `context_type: "Document"`
  → affiché dans l'offcanvas sur `documents/show.html.erb`
  → bouton "Discuter avec l'IA" sur `documents/show.html.erb` ligne ~115

---

## ✅ Ce qui a été fait (commits de la session)

### Commit `8abd9fc` — Phase 1 : Infrastructure ActionCable

**Fichiers créés :**
- `app/channels/conversation_channel.rb` (SUPPRIMÉ ensuite)
- `app/javascript/consumer.js` (SUPPRIMÉ ensuite)
- `app/javascript/channels/conversation_channel.js` (SUPPRIMÉ ensuite)

**Fichiers modifiés :**
- `config/importmap.rb` : pin `@rails/actioncable` à `actioncable.esm.js`
  + `pin_all_from "app/javascript/channels", under: "channels"`
- `app/javascript/application.js` : `import "channels/conversation_channel"`

**Pattern visé :**
```js
// conversation_channel.js
import consumer from "consumer"
consumer.subscriptions.create(
  { channel: "ConversationChannel", conversation_id: ... },
  { received(data) { Turbo.renderStreamMessage(data.html) } }
)
```

⚠️ **Problème** : extraction de l'ID depuis
`window.location.pathname.split("/").pop()` → sur `/documents/123`,
l'ID extrait est l'ID du document (123), pas de la conversation.
Le serveur `reject` la souscription (cherche `Conversation.find_by(id: 123)` → nil).

---

### Commit `9e33bdc` — Phase 2 : Service streaming + Job

**Fichiers créés :**
- `db/migrate/20260608150332_add_streaming_to_messages.rb`
  (colonne `streaming:boolean default:false null:false`)
- `app/jobs/stream_ai_response_job.rb`

**Fichiers modifiés :**
- `app/models/message.rb` :
  `validates :content, presence: true, unless: :streaming?` (le message
  peut être vide PENDANT le streaming, mais pas après)
- `app/services/open_router_service.rb` : ajout de
  - `call_streaming(&block)` : itère sur les modèles, yield chaque token
  - `streaming_faraday_call(model)` : Faraday avec
    `Accept: text/event-stream` + `stream: true` dans le body
  - `parse_sse_line(line)` : parse format `data: {json}\n\n` et
    `data: [DONE]`
  - `OpenRouterStreamError` (classe d'erreur custom)

**Job (`StreamAiResponseJob`) :**
- `FLUSH_INTERVAL_MS = 50` (50ms entre les UPDATE)
- `FLUSH_MIN_TOKENS = 4`
- Batch : accumule tokens pendant 50ms OU jusqu'à 80 chars
- `update_columns` (bypass callbacks) + `broadcast_replace` à chaque batch
- Rescue : si l'API crash, met `streaming: false` + message d'erreur
  + broadcast final

⚠️ **Gros problème initial** : le job utilise `ActionCable.server.broadcast`
sur un channel custom `conversation_#{id}`. Le client JS custom
(conversation_channel.js) doit s'abonner et appeler manuellement
`Turbo.renderStreamMessage(data.html)`.

Mais : **deux canaux distincts** :
1. `Turbo::StreamsChannel` (suscrite par `turbo_stream_from`)
2. `conversation_#{id}` (custom, mon code)

Le job broadcast sur #2, le client JS custom s'abonne à #2, mais
`turbo_stream_from` (déjà présent dans les vues) s'abonne à #1.
Résultat : le canal officiel Turbo est souscrit mais ne reçoit rien.
Le canal custom est broadcasté mais personne ne s'y abonne
correctement (l'ID est mal extrait).

**C'est le bug 1.**

---

### Commit `eb7de5f` — Phase 3+4 : Controller + Views + Chat Scroll

**Fichiers modifiés :**
- `app/controllers/messages_controller.rb` :
  - `MessagesController#create` : crée `@ai_message` VIDE + `streaming: true`
    + `StreamAiResponseJob.perform_later(@ai_message.id)` puis render
    `turbo_stream` immédiat
- `app/controllers/documents_controller.rb` :
  - `show` : crée `@doc_chat_conversation` via
    `find_or_create_by!(context_type: "Document", context_id: @document.id)`
    (nécessaire pour `turbo_stream_from` dans la page show)
- `app/views/conversations/show.html.erb` :
  `<%= turbo_stream_from @conversation %>` en haut
- `app/views/documents/show.html.erb` :
  `<%= turbo_stream_from @doc_chat_conversation %>` en haut
- `app/views/documents/_chat_panel.html.erb` :
  `<%= turbo_stream_from conversation %>` (defense en profondeur)
- `app/views/messages/_message.html.erb` :
  - Bouton voice caché si `streaming: true` (évite TTS sur texte incomplet)
  - 3 petits points qui clignotent (indicateur de génération)
  - Style `@keyframes pulse` inline
- `app/javascript/controllers/chat_scroll_controller.js` :
  MutationObserver avec `{ childList: true, subtree: true, characterData: true }`
  pour scroller aussi quand le contenu d'un message existant change
  (streaming Turbo Stream)

---

### Commit `48e670e` — Phase 5 : Tests

**Fichiers créés :**
- `test/jobs/stream_ai_response_job_test.rb` (3 tests)

**Fichiers modifiés :**
- `test/controllers/messages_controller_test.rb` : ajout d'un test
  vérifie que `@ai_message` est créé vide + `streaming: true` + job enqueue

**Stub pattern utilisé** (pas de mocha dans le projet) :
```ruby
# Stub au niveau classe, pas singleton
original = OpenRouterService.instance_method(:call_streaming)
OpenRouterService.define_method(:call_streaming) do |&block|
  tokens.each { |t| block.call(t) }
  content
end
# ensure: restore
OpenRouterService.define_method(:call_streaming, original)
```

**Problème rencontré** : `define_singleton_method` ne marche PAS sur
des méthodes d'instance — il faut `define_method` au niveau classe.
Le `define_method` partage l'état entre threads, donc en exécution
parallélisée ça peut fuir entre tests. Solution : `teardown` qui
restaure toujours.

Pour stub `Turbo::StreamsChannel.broadcast_replace_to` : pareil,
`Turbo::StreamsChannel.define_singleton_method` (c'est une méthode
de classe car le module est étendu).

---

### Commit `f9aa928` — Fix Bug 1 : utiliser Turbo::StreamsChannel (CHANGEMENT MAJEUR)

**Constat** : le `conversation_channel.js` custom + `ActionCable.server.broadcast`
sont des couches en trop. Le pattern Rails/Hotwire canonique est
`Turbo::StreamsChannel.broadcast_replace_to(streamable, target:, partial:)` —
Turbo côté client sait déjà traiter ce format HTML standard.

**Modifications :**
- `StreamAiResponseJob#broadcast_replace` :
  ```ruby
  Turbo::StreamsChannel.broadcast_replace_to(
    @message.conversation,
    target: ActionView::RecordIdentifier.dom_id(@message),
    partial: "messages/message",
    locals: { message: @message }
  )
  ```
- **Supprimé** : `app/channels/conversation_channel.rb` (devenu inutile)
- **Supprimé** : `app/javascript/channels/conversation_channel.js`
- **Supprimé** : `app/javascript/consumer.js` (plus de ActionCable JS custom)
- `app/javascript/application.js` : retire l'import du channel custom
- `config/importmap.rb` : retire pin `@rails/actioncable` (plus utilisé)

**Avantages :**
- Pattern canonique, pas de JS custom
- Marche pour chat principal ET doc-chat offcanvas (les 2 ont
  `turbo_stream_from` sur la même conv ou une conv différente)
- Format turbo_stream standard, parsé nativement par Turbo

---

### Commit `713b60d` — Fix Bug 2 : Bootstrap UMD vs ESM

**Constat** : la gem `bootstrap-5.3.8` distribue `bootstrap.min.js` en
**UMD** (Universal Module Definition), pas en ES Module. Le code
commence par `!function(t,e){"object"==typeof exports&&"undefined"!=typeof
module?module.exports=e(require("@popperjs/core")):...`. Quand
importmap fait `import "bootstrap"`, le module ESM charge un fichier
UMD qui ne fait rien (CommonJS non détecté). Résultat : le JS
Bootstrap n'est jamais exécuté → `data-bs-toggle="offcanvas"`
ne déclenche rien.

**Symptôme** : clic sur le bouton "Discuter avec l'IA" dans
`documents/show.html.erb` ne faisait rien. L'offcanvas Bootstrap
ne s'ouvrait pas. (Le CSS marchait via Sprockets.)

**Fix** : pointer l'importmap vers le bundle ESM officiel via CDN :
```ruby
pin "bootstrap", to: "https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js", preload: true
```

Le bundle inclut Popper.js (donc on pourrait retirer le pin Popper,
mais on l'a laissé pour la compat).

**Luis a confirmé** : le bug 2 (offcanvas ne s'ouvre pas) est résolu
après le fix.

---

## 🐛 Bug 1 toujours présent après les fixes

**État** : Luis a testé en browser après les 2 fixes :
- ✅ Bug 2 résolu : le bouton "Discuter" fonctionne, l'offcanvas s'ouvre
- ❌ Bug 1 toujours présent : la bulle AI reste figée sur les 3 points
  (indicateur streaming), même si la réponse est bien générée en base
  (visible après reload manuel de la page)

### Hypothèses à investiguer dans la prochaine session

**Hypothèse #1 (probabilité haute) : la migration n'a pas été appliquée**
- Le user de test en local a bien la migration `20260608150332` appliquée
- Mais si Luis teste sur un environnement où `db:migrate` n'a pas été
  lancé, la colonne `streaming` n'existe pas → erreur silencieuse
  → `update!(streaming: true)` raise → broadcast jamais appelé

**Hypothèse #2 (probabilité haute) : Faraday est synchrone, l'API met 30s**
- `Faraday.post(...)` lit tout le body avant de yield
- `response.body.each_line` itère sur les lignes déjà reçues
- L'utilisateur voit les 3 points pendant 30s puis tout apparaît d'un coup
- ⚠️ C'est un fix futur, mais ça n'explique pas le "figé définitif"
- Le `streaming: false` est bien mis à la fin, donc le client devrait
  finir par voir le replace

**Hypothèse #3 (probabilité moyenne) : Turbo::StreamsChannel.broadcast_replace_to ne marche pas comme attendu**
- Vérifier dans les logs Rails si l'appel broadcast_replace_to lève
- Vérifier que `Turbo::Streams::StreamName.signed_stream_name(@message.conversation)`
  matche ce que `turbo_stream_from @conversation` génère
- Possible mismatch : `turbo_stream_from @conversation` utilise
  `verified_stream_name_from_params` qui attend un `signed_stream_name`
  signé via `Turbo.signed_stream_verifier`
- Si le stream_name calculé par `broadcast_replace_to` diffère
  légèrement de celui calculé par `turbo_stream_from`, les broadcasts
  sont perdus silencieusement

**Hypothèse #4 (probabilité moyenne) : le format du partial est mauvais**
- `Turbo::StreamsChannel.broadcast_replace_to` rend le partial via
  `ApplicationController.renderer.render(partial: "messages/message", locals: { message: @message })`
- Le partial utilise `markdown(message.content.to_s)` qui est peut-être
  lent ou en erreur si message.content est vide
- Vérifier que le partial rend bien sans erreur

**Hypothèse #5 (probabilité faible) : Solid Queue ne tourne pas en dev**
- `SOLID_QUEUE_IN_PUMA=1` dans `.env` fait tourner le worker in-process
- Si le serveur dev n'a pas été redémarré après l'ajout du job, le
  worker peut être dans un état bizarre
- Solution : redémarrer le serveur, vérifier les logs `Solid Queue`

**Hypothèse #6 (probabilité moyenne) : `Turbo::StreamsChannel.broadcast_replace_to` attend des arguments positionnels différents**
- Vu dans la doc : `broadcast_replace_to(*streamables, **opts)`
- `*streamables` peut être `[conversation]` (1) ou `[conversation, partial: ...]` (2) ?
- En réalité, `opts` contient `target:`, `partial:`, `locals:`
- Le partial est passé en string nom

### Comment debugger

1. **Console Rails en dev** : `bin/rails console` puis :
   ```ruby
   conv = User.first.conversations.last
   msg = conv.messages.where(role: "assistant").last
   msg.update!(streaming: true)  # reset pour tester
   StreamAiResponseJob.perform_now(msg.id)
   ```
   → voir si l'erreur apparaît dans la console

2. **Logs Rails dev** : `tail -f log/development.log` pendant qu'un user
   envoie un message. Chercher :
   - `StreamAiResponseJob` (démarre)
   - `Turbo::StreamsChannel` (broadcasts)
   - Erreurs potentielles

3. **Console JS browser** : ouvrir DevTools → onglet Network → filtrer
   par "ws" ou "cable". Vérifier qu'une connexion WebSocket est
   ouverte. Puis envoyer un message et voir si des messages WS
   arrivent.

4. **Test de broadcast manuel** : `bin/rails runner` puis :
   ```ruby
   msg = Message.last
   Turbo::StreamsChannel.broadcast_replace_to(
     msg.conversation,
     target: ActionView::RecordIdentifier.dom_id(msg),
     partial: "messages/message",
     locals: { message: msg }
   )
   ```
   → si le browser ne reçoit rien, c'est que le format est mauvais

5. **Inspecter le HTML généré** : ajouter un `puts` dans le job pour
   voir exactement ce qui est broadcasté :
   ```ruby
   def broadcast_replace
     html = ApplicationController.render(
       partial: "messages/message",
       locals: { message: @message },
       layout: false
     )
     Rails.logger.debug "BROADCAST HTML: #{html.first(500)}"
     Turbo::StreamsChannel.broadcast_replace_to(...)
   end
   ```

---

## 📂 Fichiers de la branche `feature/ai-streaming`

### Créés
- `db/migrate/20260608150332_add_streaming_to_messages.rb`
- `app/jobs/stream_ai_response_job.rb`
- `test/jobs/stream_ai_response_job_test.rb`

### Supprimés (dans les fixes)
- `app/channels/conversation_channel.rb` (obsolète)
- `app/javascript/channels/conversation_channel.js` (obsolète)
- `app/javascript/consumer.js` (obsolète)

### Modifiés
- `app/controllers/messages_controller.rb` (streaming: true + job enqueue)
- `app/controllers/documents_controller.rb` (`@doc_chat_conversation` dans show)
- `app/javascript/application.js` (retire import channel)
- `app/models/message.rb` (`validates :content, ..., unless: :streaming?`)
- `app/services/open_router_service.rb` (`call_streaming`, `streaming_faraday_call`, `parse_sse_line`)
- `app/javascript/controllers/chat_scroll_controller.js` (characterData observer)
- `app/views/messages/_message.html.erb` (bouton voice conditionnel + 3 points)
- `app/views/conversations/show.html.erb` (turbo_stream_from)
- `app/views/documents/show.html.erb` (turbo_stream_from + create_doc_chat.turbo_stream.erb)
- `app/views/documents/_chat_panel.html.erb` (turbo_stream_from)
- `app/views/messages/create.turbo_stream.erb` (intact, append user + AI)
- `app/views/messages/create_doc_chat.turbo_stream.erb` (intact)
- `config/importmap.rb` (Bootstrap → CDN ESM, retire @rails/actioncable)
- `test/controllers/messages_controller_test.rb` (+1 test)

### État GitHub
- 2 commits pushés sur `feature/ai-streaming` (PAS MERGÉE) :
  - `f9aa928` fix(streaming)
  - `713b60d` fix(bootstrap)
- PR existe sur GitHub : `feature/ai-streaming`
- Luis n'a pas mergé (feature cassée à cause du bug 1)

---

## 🧪 État des tests

```
bin/rails test
→ 208 runs, 411 assertions, 0 failures, 0 errors, 0 skips
```

Les 3 tests du job streaming passent (avec stubs). MAIS ils ne
testent pas l'intégration Turbo::StreamsChannel réelle — ils capturent
l'appel `broadcast_replace_to` mais ne vérifient pas qu'un client
reçoit vraiment le replace.

Tests à ajouter dans la prochaine session :
- Test d'intégration : créer un Message, broadcaster manuellement,
  vérifier que la signature du broadcast est conforme
- Test du format HTML : `Turbo::StreamsChannel.broadcast_replace_to`
  doit produire un HTML qui passe le parser Turbo

---

## 🔧 Commandes utiles pour la prochaine session

```bash
# Voir l'état actuel
git status
git log --oneline -10

# Démarrer le serveur en dev
bin/rails server -p 3456 -d

# Watcher les logs en temps réel
tail -f log/development.log | grep -i "stream\|broadcast\|cable"

# Console Rails pour debug
bin/rails console
> conv = User.find_by(email: "test_sidebar@mindsnap.test").conversations.last
> msg = conv.messages.where(role: "assistant").last
> msg.update!(streaming: true)
> StreamAiResponseJob.perform_now(msg.id)
> msg.reload.content
> msg.streaming

# Test broadcast manuel (sans job)
bin/rails runner '
msg = Message.last
Turbo::StreamsChannel.broadcast_replace_to(
  msg.conversation,
  target: ActionView::RecordIdentifier.dom_id(msg),
  partial: "messages/message",
  locals: { message: msg }
)
puts "Broadcast done"
'

# Reset DB de test
bin/rails db:reset
bin/rails db:migrate
```

---

## 📝 Leçons à retenir pour la prochaine session

1. **Le streaming Faraday n'est PAS un vrai streaming HTTP** — `Faraday.post`
   lit tout le body avant de yield. Pour un vrai streaming HTTP chunked,
   il faut `Net::HTTP` avec lecture manuelle, ou `Faraday` avec
   middleware `:stream_body`. Mais ce n'est pas la cause du "figé".

2. **Le pattern Hotwire canonique pour le streaming** est :
   - `turbo_stream_from @model` dans la vue
   - `Turbo::StreamsChannel.broadcast_*_to(@model, ...)` dans le job
   - **AUCUN channel ActionCable custom nécessaire** — Turbo fait tout

3. **L'extraction d'ID depuis l'URL est fragile** — préférer toujours
   injecter l'ID via data-attribute, meta tag, ou en passant par le
   modèle directement (broadcast_replace_to prend le model).

4. **Bootstrap 5 via gem + importmap** = UMD chargé comme ESM = rien
   ne marche. Utiliser le bundle ESM depuis CDN, ou via Sprockets.

5. **Test en browser > test curl** : la stack Turbo + ActionCable + DOM
   a trop de pièces mobiles. Les tests Ruby passent mais le browser
   peut être cassé.

6. **Solid Queue in-process** (`SOLID_QUEUE_IN_PUMA=1`) : le worker
   tourne sur un thread Puma. Si le serveur n'est pas redémarré
   après un changement, les nouveaux jobs peuvent ne pas être
   picked up. **Toujours redémarrer le serveur dev après modif de job.**

---

## 🎯 TODO pour la prochaine session

1. **Debugger le bug 1** (streaming figé) :
   - [ ] Console Rails : `StreamAiResponseJob.perform_now(msg.id)` à la main
   - [ ] Logs Rails dev : grep "stream" pendant un envoi de message
   - [ ] Console JS browser : vérifier la connexion WebSocket + messages
   - [ ] Test manuel du broadcast : `Turbo::StreamsChannel.broadcast_replace_to(...)` direct
   - [ ] Inspecter le HTML généré par le broadcast
   - [ ] Vérifier la cohérence entre `turbo_stream_from` (côté vue) et `broadcast_replace_to` (côté job) au niveau du stream_name signé

2. **Si le bug est dans Turbo::StreamsChannel** :
   - Vérifier que `Turbo::Streams::StreamName.signed_stream_name` matche
   - Possible solution : utiliser `Turbo::Streams::Broadcasts.broadcast_replace_to` directement
   - Ou : ajouter un fallback plus verbeux qui broadcast dans les 2 canaux (custom + officiel) en attendant

3. **Fix le vrai streaming HTTP** (post-bug 1) :
   - Remplacer `Faraday.post` synchrone par `Net::HTTP` streaming
   - Ou ajouter `req.options.on_data = callback` à Faraday pour vrai streaming

4. **Tester en prod après merge** :
   - `heroku run rails db:migrate` (applique la migration `streaming`)
   - Vérifier que Solid Queue tourne (Heroku single dyno)

---

## 🔗 Liens utiles

- PR : https://github.com/G2025-mahfoudhi/mindSnap/pull/new/feature/ai-streaming
- Branch : `feature/ai-streaming` (commits `f9aa928` et `713b60d` non mergés)
- Turbo docs : https://turbo.hotwired.dev/reference/streams
- Turbo::StreamsChannel source : `/Users/rushford/.rbenv/versions/3.3.5/lib/ruby/gems/3.3.0/gems/turbo-rails-2.0.23/app/channels/turbo/streams_channel.rb`
- Bootstrap ESM bundle : https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js
- OpenRouter SSE format : OpenAI-compatible (`data: {json}\n\ndata: [DONE]\n\n`)

---

**Session terminée le 2026-06-08 vers 15h30.**
**Branche non mergée — bug streaming à résoudre dans la prochaine session.**
