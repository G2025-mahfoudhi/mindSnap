# Téléchargement de fichiers depuis Cloudinary — MindSnap

**Date :** 03 juin 2026
**Projet :** MindSnap — Rails 8.1.3 + Active Storage + Cloudinary

---

## Situation de départ

Le bouton "Télécharger" existait dans la vue `show` d'un document
mais ne fonctionnait pas en production (Heroku + Cloudinary).

---

## Ce qui existait avant (code original)

### `config/routes.rb`
```ruby
resources :documents, only: %I[index new edit show create update]
# Pas de route :destroy, pas de route :download
```

### `app/controllers/documents_controller.rb`
```ruby
class DocumentsController < ApplicationController
  before_action :set_document, only: %i[show edit update destroy]
  # Pas d'action download
  # show vide, destroy redirige vers documents_path sans vérifier le dossier
end
```

### `app/views/documents/show.html.erb`
```erb
# Pas de bouton télécharger
# Pas d'accès aux fichiers attachés
# Lien "Modifier" et "Supprimer" simples
```

---

## Problèmes rencontrés et résolutions (dans l'ordre)

---

### Problème 3 — `resource_type` manquant dans `storage.yml`

**Symptôme :** Seules les images fonctionnaient. PDFs, DOCX, ZIP
et autres types étaient refusés ou irrécupérables.

**Cause :** Sans `resource_type`, Cloudinary traite tous les fichiers
comme des images (`image` par défaut). Les fichiers non-image échouaient.

**Avant :**
```yaml
cloudinary:
  service: Cloudinary
  folder: <%= Rails.env %>
```

**Après :**
```yaml
cloudinary:
  service: Cloudinary
  folder: <%= Rails.env %>
  resource_type: auto
```

`resource_type: auto` permet à Cloudinary de détecter automatiquement
le bon type (image, video, raw) pour chaque fichier uploadé.

---

### Problème 4 — Pas de route ni d'action `download`

**Cause :** Aucune route dédiée au téléchargement n'existait.
La vue utilisait `rails_blob_path` (redirect Active Storage générique)
qui redirige vers une URL Cloudinary publique.

**Avant dans `routes.rb` :**
```ruby
resources :documents, only: %I[index new edit show create update]
```

**Après dans `routes.rb` :**
```ruby
resources :documents do
  member do
    get :download
  end
end
```

**Action ajoutée dans `documents_controller.rb` :**
```ruby
before_action :set_document, only: %i[show edit update destroy download]

def download
  blob = ActiveStorage::Blob.find_signed!(params[:blob_signed_id])

  unless @document.file.map { |a| a.blob.id }.include?(blob.id)
    raise ActiveRecord::RecordNotFound
  end

  resource_type = cloudinary_resource_type(blob.content_type)
  public_id     = "#{Rails.env}/#{blob.key}"

  url = Cloudinary::Utils.cloudinary_url(
    public_id,
    resource_type: resource_type,
    type:          "upload",
    flags:         "attachment:#{File.basename(blob.filename.to_s, '.*').gsub(' ', '_')}",
    secure:        true
  )

  redirect_to url, allow_other_host: true
end

private

def cloudinary_resource_type(content_type)
  case content_type
  when /\Aimage\//           then "image"
  when /\Avideo\//           then "video"
  when "application/pdf"     then "image"
  else                            "raw"
  end
end
```

**Vue `show.html.erb` — lien mis à jour :**
```erb
<%# Avant %>
<%= link_to rails_blob_path(attachment, disposition: "attachment"), ... %>

<%# Après %>
<%= link_to download_document_path(@document,
              blob_signed_id: attachment.blob.signed_id), ... %>
```

---

### Problème 5 — URL de livraison invalide `/auto/upload/`

**Symptôme :** Erreur 400 sur l'URL Cloudinary générée.

**Cause :** Le gem Cloudinary v2.4.5 utilise `resource_type: auto`
(défini dans `storage.yml`) aussi bien pour l'upload que pour générer
les URLs de livraison. Or `auto` est uniquement valide à l'upload —
pour les URLs de livraison, Cloudinary n'accepte que `image`, `video` ou `raw`.

URL générée (invalide) :
```
https://res.cloudinary.com/mindsnap/auto/upload/v1/production/xxx.pdf
```

**Solution :** Générer l'URL manuellement via `Cloudinary::Utils.cloudinary_url`
en déterminant le `resource_type` à partir du `content_type` du fichier
(voir méthode `cloudinary_resource_type` ci-dessus).

URL générée (valide) :
```
https://res.cloudinary.com/mindsnap/image/upload/fl_attachment:Mon_Fichier/v1/production/xxx
```

---

### Problème 6 — Fichier téléchargé renommé en "cloudinaryfile"

**Symptôme :** Le fichier se téléchargeait correctement mais sous le nom
`cloudinaryfile.pdf` au lieu du nom original.

**Cause :** Le flag `fl_attachment` sans nom de fichier laisse Cloudinary
utiliser son nom par défaut (`cloudinaryfile`).

**Solution :** Passer le nom dans le flag : `fl_attachment:nom_du_fichier`.

---

### Problème 7 — Erreur 400 avec le nom de fichier dans le flag

**Symptôme :** Erreur 400 dès qu'un nom de fichier était spécifié dans le flag.

**Deux causes :**

1. **Espaces dans le nom** — `fl_attachment:Wott Tutorial.pdf` est une URL invalide.
   Fix : remplacer les espaces par des underscores.

2. **Extension `.pdf` dans le flag** — `fl_attachment:nom.pdf` est interprété
   par Cloudinary comme un paramètre de format, causant un conflit.
   Fix : retirer l'extension du flag. Cloudinary l'ajoute automatiquement
   selon le format réel du fichier.

**Solution finale :**
```ruby
flags: "attachment:#{File.basename(blob.filename.to_s, '.*').gsub(' ', '_')}"
# "Wott Tutorial.pdf" → "Wott_Tutorial" dans le flag
# Cloudinary livre le fichier comme : Wott_Tutorial.pdf ✓
```

**Vérification :**
```bash
curl -sI "https://res.cloudinary.com/mindsnap/image/upload/fl_attachment:Wott_Tutorial/..."
# content-disposition: attachment; filename="Wott_Tutorial.pdf" ✓
```

---

## État final du code

### `config/storage.yml`
```yaml
cloudinary:
  service: Cloudinary
  folder: <%= Rails.env %>
  resource_type: auto
```

### `config/routes.rb`
```ruby
resources :documents do
  member do
    get :download
  end
end
```

### `app/controllers/documents_controller.rb` (parties modifiées)
```ruby
before_action :set_document, only: %i[show edit update destroy download]

def download
  blob = ActiveStorage::Blob.find_signed!(params[:blob_signed_id])
  unless @document.file.map { |a| a.blob.id }.include?(blob.id)
    raise ActiveRecord::RecordNotFound
  end
  resource_type = cloudinary_resource_type(blob.content_type)
  public_id     = "#{Rails.env}/#{blob.key}"
  url = Cloudinary::Utils.cloudinary_url(
    public_id,
    resource_type: resource_type,
    type:          "upload",
    flags:         "attachment:#{File.basename(blob.filename.to_s, '.*').gsub(' ', '_')}",
    secure:        true
  )
  redirect_to url, allow_other_host: true
end

def cloudinary_resource_type(content_type)
  case content_type
  when /\Aimage\//       then "image"
  when /\Avideo\//       then "video"
  when "application/pdf" then "image"
  else                        "raw"
  end
end
```

### `app/views/documents/show.html.erb` (lien téléchargement)
```erb
<%= link_to download_document_path(@document,
              blob_signed_id: attachment.blob.signed_id),
            class: "btn btn-outline-primary btn-sm",
            aria: { label: "Télécharger #{attachment.filename}" } do %>
  <i class="fa-solid fa-download fa-xs me-1" aria-hidden="true"></i>
  <%= attachment.filename.to_s.truncate(25) %>
<% end %>
```

---

## Flux de téléchargement final

```
Clic sur "Télécharger"
        ↓
GET /documents/:id/download?blob_signed_id=...
        ↓
DocumentsController#download
  1. Vérifie que le blob appartient au document (sécurité)
  2. Détermine le resource_type selon le content-type
  3. Génère une URL Cloudinary valide avec fl_attachment
        ↓
302 redirect → https://res.cloudinary.com/mindsnap/image/upload/fl_attachment:Nom_Fichier/...
        ↓
Navigateur télécharge directement depuis le CDN Cloudinary
Content-Disposition: attachment; filename="Nom_Fichier.pdf"
```

---

## Comprendre ActiveStorage::Blob

**Blob** = Binary Large Object. C'est la classe Rails qui représente un fichier
stocké, quelle que soit sa destination (disque local, Cloudinary, S3...).

---

### Ce qu'il contient en base de données

Quand tu uploades un fichier, Rails crée **deux enregistrements** :

**`active_storage_blobs`** — les métadonnées du fichier :

| Colonne | Contenu |
|---|---|
| `key` | identifiant unique du fichier sur le service de stockage |
| `filename` | nom original (`Wott Tutorial.pdf`) |
| `content_type` | `application/pdf`, `image/png`... |
| `byte_size` | taille en octets |
| `checksum` | empreinte pour vérifier l'intégrité |
| `service_name` | `cloudinary`, `local`... |

**`active_storage_attachments`** — le lien entre le blob et ton modèle :

| Colonne | Contenu |
|---|---|
| `record_type` | `"Document"` |
| `record_id` | l'id du document |
| `blob_id` | l'id du blob |
| `name` | `"file"` (le nom de l'association) |

---

### Dans le code du projet

```ruby
# Document a plusieurs fichiers attachés
has_many_attached :file

# Quand tu écris @document.file, tu obtiens une collection d'attachments
# Chaque attachment pointe vers un blob
@document.file.each do |attachment|
  attachment.blob       # => le blob (métadonnées)
  attachment.blob.key   # => "chtutl3vybbchrqbnwv1mvtjtwwi" (clé Cloudinary)
  attachment.filename   # => "Wott Tutorial.pdf"
end
```

Dans l'action `download` :

```ruby
# On retrouve le blob via son signed_id (token signé par Rails, infalsifiable)
blob = ActiveStorage::Blob.find_signed!(params[:blob_signed_id])

blob.key          # => clé du fichier sur Cloudinary
blob.filename     # => nom original
blob.content_type # => "application/pdf"
blob.download     # => télécharge le contenu binaire depuis Cloudinary
blob.url(...)     # => génère une URL de livraison (avec le bug /auto/upload/)
```

---

### Pourquoi `find_signed!` et pas `find` ?

```ruby
# find(id) — utilise l'id en clair, falsifiable :
# /documents/7/download?blob_id=8  → un utilisateur peut changer l'id manuellement

# find_signed!(token) — utilise un token signé avec la clé secrète Rails :
# /documents/7/download?blob_signed_id=eyJfcmFpbHMi...
# Si le token est modifié → exception ActiveSupport::MessageVerifier::InvalidSignature
```

C'est pourquoi dans la vue on passe `attachment.blob.signed_id` (pas `.id`)
et dans le controller on vérifie en plus que le blob appartient bien
au document de l'utilisateur connecté :

```ruby
unless @document.file.map { |a| a.blob.id }.include?(blob.id)
  raise ActiveRecord::RecordNotFound
end
```

Cette double vérification empêche un utilisateur de télécharger
les fichiers d'un autre en devinant ou en modifiant les paramètres.

---

## Commandes utiles

```bash
# Vérifier les migrations en production
heroku run rails db:migrate:status --app our-mindsnap

# Tester la connexion Cloudinary
heroku run rails runner "require 'cloudinary'; puts Cloudinary::Api.ping" --app our-mindsnap

# Voir les fichiers stockés
heroku run rails runner \
  "puts ActiveStorage::Blob.all.map { |b| [b.filename, b.key, b.content_type] }.inspect" \
  --app our-mindsnap

# Logs en direct
heroku logs --tail --app our-mindsnap
```
