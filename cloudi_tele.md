# Téléchargement de fichiers depuis Cloudinary — MindSnap

**Date :** 03 juin 2026  
**Projet :** MindSnap (Rails 8.1.3 + Cloudinary + Active Storage)

---

## Contexte

L'application MindSnap permet aux utilisateurs d'uploader des fichiers (PDF, DOCX, etc.)
attachés à leurs documents. Ces fichiers sont stockés sur Cloudinary en production.
L'objectif était de faire fonctionner le bouton "Télécharger" sur la page `show` d'un document.

---

## Problèmes rencontrés et solutions

### 1. Base de données vide en production

**Symptôme :** Erreur 500 sur toutes les pages, y compris `/users/sign_up`.

**Cause :** Aucune migration n'avait jamais été exécutée sur Heroku.
La table `schema_migrations` n'existait pas. Rails ne pouvait même pas
instancier un objet `User` pour afficher le formulaire d'inscription.

**Solution :**
```bash
heroku run rails db:migrate --app our-mindsnap
```

---

### 2. CLOUDINARY_URL incorrecte

**Symptôme :** Les fichiers uploadés n'apparaissaient pas dans Cloudinary.
L'API Cloudinary répondait `cloud_name mismatch`.

**Cause :** Le `cloud_name` dans la variable `CLOUDINARY_URL` était `dpm4v9e57`
alors que le vrai cloud name du compte est `mindsnap`.
Les uploads échouaient silencieusement : les enregistrements étaient créés
en base de données mais les fichiers n'atteignaient jamais Cloudinary.

**Solution :** Corriger la `CLOUDINARY_URL` sur Heroku :
```bash
heroku config:set CLOUDINARY_URL=cloudinary://API_KEY:API_SECRET@mindsnap \
  --app our-mindsnap
```

---

### 3. `resource_type` manquant dans `storage.yml`

**Fichier :** `config/storage.yml`

**Symptôme :** Seules les images fonctionnaient. Les PDFs, DOCX, ZIP
et autres types de fichiers étaient refusés ou irrécupérables.

**Cause :** Sans `resource_type`, Cloudinary traitait tous les fichiers
comme des images (`resource_type: image` par défaut).

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
le bon type pour chaque fichier (image, video, raw).

---

### 4. Téléchargement bloqué par "Strict Transformations"

**Symptôme :** Erreur 401 sur toutes les URLs Cloudinary, même signées.

**Cause :** Le compte Cloudinary avait l'option "Strict Transformations" activée,
ce qui bloque l'accès direct à toutes les URLs publiques CDN.
L'ancienne implémentation utilisait `rails_blob_path` qui redirige
le navigateur vers une URL Cloudinary publique — bloquée par ce paramètre.

**Solution :** Remplacer le redirect par un téléchargement côté serveur.
Rails télécharge le fichier depuis Cloudinary via les credentials API
(accès privé, non soumis aux restrictions publiques), puis le transmet
directement au navigateur.

---

## Modifications apportées au code

### `config/routes.rb`

Ajout d'une route `download` dédiée sur les documents :

```ruby
resources :documents do
  member do
    get :download
  end
end
```

---

### `app/controllers/documents_controller.rb`

Ajout de `download` dans le `before_action` et création de l'action :

```ruby
before_action :set_document, only: %i[show edit update destroy download]

def download
  blob = ActiveStorage::Blob.find_signed!(params[:blob_signed_id])

  # Sécurité : vérifier que le blob appartient bien à ce document
  unless @document.file.map { |a| a.blob.id }.include?(blob.id)
    raise ActiveRecord::RecordNotFound
  end

  # Téléchargement via Rails (credentials API serveur)
  # Contourne les restrictions d'accès public Cloudinary
  send_data blob.download,
            filename: blob.filename.to_s,
            type: blob.content_type,
            disposition: "attachment"
end
```

---

### `app/views/documents/show.html.erb`

Remplacement du lien Active Storage générique par la nouvelle route :

```erb
<%# Avant %>
<%= link_to rails_blob_path(attachment, disposition: "attachment"), ... %>

<%# Après %>
<%= link_to download_document_path(@document,
              blob_signed_id: attachment.blob.signed_id), ... %>
```

---

### Bugs critiques corrigés dans la vue

Deux erreurs avaient été introduites manuellement dans `show.html.erb` :

**Bug 1 — `NoMethodError` à chaque visite de la page :**
```erb
<%# Faux — .file est une collection, .key n'existe pas dessus %>
download_document_path(@document.file.key, ...)

<%# Correct %>
download_document_path(@document, ...)
```

**Bug 2 — Suppression de tous les fichiers Cloudinary à chaque chargement :**
```erb
<%# Faux — .file.purge() s'exécute lors du rendu HTML, pas au clic %>
<%# Cela supprimait tous les fichiers à chaque visite de la page %>
document_path(@document.file.purge)

<%# Correct %>
document_path(@document)
```

---

## Déploiement

Le code était sur la branche `download` et n'avait jamais été déployé.
Commande utilisée pour déployer sur Heroku :

```bash
git push heroku download:master
```

---

## Résumé du flux de téléchargement final

```
Utilisateur clique "Télécharger"
        ↓
GET /documents/:id/download?blob_signed_id=...
        ↓
DocumentsController#download
  → vérifie que le blob appartient au document
  → blob.download  (appel API Cloudinary côté serveur)
        ↓
Cloudinary retourne le fichier au serveur Rails
        ↓
send_data → navigateur reçoit le fichier
  Content-Disposition: attachment
  Content-Type: application/pdf (ou autre)
```

---

## Commandes utiles

```bash
# Vérifier les migrations en production
heroku run rails db:migrate:status --app our-mindsnap

# Vérifier la connexion Cloudinary
heroku run rails runner "require 'cloudinary'; puts Cloudinary::Api.ping" \
  --app our-mindsnap

# Voir les blobs en base
heroku run rails runner \
  "puts ActiveStorage::Blob.all.map { |b| [b.filename, b.key] }.inspect" \
  --app our-mindsnap

# Logs en direct
heroku logs --tail --app our-mindsnap
```
