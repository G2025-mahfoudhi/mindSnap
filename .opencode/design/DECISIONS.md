# 📋 Décisions de design — MindSnap

> Suivi chronologique des choix de design, leur justification, et le contexte.
> À mettre à jour à chaque décision impactant le front-end.

---

## Décision 001 — Palette de couleurs

**Date :** 2026-06-02 (session initiale)
**Contexte :** Définition de l'identité visuelle du projet.
**Décision :** Palette basée sur un teal (`#549695`) comme accent principal.
**Raison :**
- Le teal évoque la confiance, la sérénité, l'intelligence — cohérent avec « deuxième cerveau »
- Contraste suffisant sur fond blanc pour les éléments d'accent
- Assez distinct pour être mémorisable, pas trop agressif
**Alternatives rejetées :**
- Bleu standard : trop générique, déjà utilisé par 90% des SaaS
- Vert vif : trop orienté « écologie »
- Violet : trop créatif, moins « fiable »

---

## Décision 002 — Polices (Nunito + Work Sans)

**Date :** 2026-06-02 (template Le Wagon)
**Décision :** Nunito pour les titres, Work Sans pour le corps.
**Raison :**
- Nunito : géométrique et chaleureuse, bon impact visuel pour les titres
- Work Sans : lisible à petite taille, neutre, efficace pour le corps
- Les deux sont sur Google Fonts (gratuit, rapide)
- Cohérent avec le template Le Wagon (pas besoin de télécharger des fonts custom)
**Alternatives rejetées :**
- Inter : excellente mais onboarding plus complexe
- System fonts : trop générique, pas d'identité

---

## Décision 003 — Bootstrap 5.3 natif (pas Tailwind)

**Date :** 2026-06-02 (template Le Wagon)
**Décision :** Rester sur Bootstrap 5.3 + SCSS via Sprockets.
**Raison :**
- Le projet est généré via le template Le Wagon qui utilise Bootstrap
- Migration vers Tailwind = refonte totale du pipeline CSS (Sprockets → cssbundling)
- Bootstrap est suffisant pour les besoins du projet
- L'équipe/les agents sont optimisés pour Bootstrap
**Alternatives rejetées :**
- Tailwind CSS : nécessiterait une migration lourde, pas de valeur ajoutée immédiate

---

## Décision 004 — Organisation SCSS (config/components/pages)

**Date :** 2026-06-02 (template Le Wagon)
**Décision :** Structure en 3 dossiers : `config/`, `components/`, `pages/`.
**Raison :**
- Pattern standard Le Wagon, éprouvé sur des centaines de projets
- Séparation claire : variables → composants réutilisables → styles spécifiques aux pages
- Facilite la contribution des agents IA (prévisibilité)

---

## Décision 005 — Layout Devise : `layout_by_resource` (layout séparé)

**Date :** 2026-06-02 (session DEVISE)
**Contexte :** Besoin d'un layout épuré pour les pages d'auth (pas de navbar, pas de footer).
**Décision :** Utiliser `layout :layout_by_resource` dans `ApplicationController` pour switcher vers `layouts/devise.html.erb` sur les pages Devise.
**Raison :**
- Pattern officiel recommandé par la doc Devise et la communauté Rails
- Layout devise complètement indépendant (changer le `<head>`, le fond, la structure sans impacter le layout principal)
- Plus propre qu'une condition `unless devise_controller?` dans `application.html.erb`
- Évolutif : si un jour on veut un layout onboarding différent, on peut ajouter un cas
**Alternatives rejetées :**
- Condition dans `application.html.erb` : fonctionne mais mélange les responsabilités, limitant
**Sources :**
- Doc Devise wiki : [How To: Create custom layouts](https://github.com/heartcombo/devise/wiki/How-To:-Create-custom-layouts)
- GoRails, Stack Overflow (pattern récurrent)

---

## Décision 006 — Auth layout : fond warm-gray

**Date :** 2026-06-02 (session DEVISE)
**Décision :** Fond `#F7F5F4` (warm-gray) pour toutes les pages d'auth.
**Raison :**
- Cohérent avec la section Features de la homepage qui utilise déjà ce fond
- La carte blanche se détache bien sur fond gris chaud
- Plus chaleureux qu'un fond blanc uniforme
- Distinction visuelle claire entre « zone publique » (homepage) et « zone d'auth » (devise)

---

## Décision 007 — Auth layout desktop : 2 colonnes

**Date :** 2026-06-02 (session DEVISE)
**Décision :** Layout desktop en 2 colonnes : formulaire à gauche, illustration + citation à droite.
**Raison :**
- Utilise l'espace desktop efficacement
- La colonne droite avec citation renforce le message produit
- Cohérent avec la section Hero de la homepage (2 colonnes aussi)
- Sur mobile, la colonne droite disparaît → carte seule centrée (simple)
**Partials :** `devise/shared/_auth_sidebar` paramétrable selon la page.

---

## Décision 008 — Champs `first_name` et `last_name` obligatoires

**Date :** 2026-06-02 (session DEVISE)
**Décision :** Ajouter `first_name` et `last_name` au formulaire d'inscription et d'édition de profil.
**Raison :**
- Le modèle User les exige déjà (`validates :first_name, presence: true`)
- Essentiel pour personnaliser l'expérience (bonjour Prénom)
- Standard dans les SaaS grand public
**Implémentation :** Strong Parameters dans `ApplicationController` via `devise_parameter_sanitizer.permit(:sign_up, keys: [...])`

---

## Décision 009 — Illustrations sidebar auth

**Date :** 2026-06-02 (session DEVISE)
**Décision :** Réutiliser les SVGs Undraw existants à la racine du projet.
**Raison :**
- Déjà présents, pas besoin d'en télécharger de nouveaux
- Style Undraw cohérent avec la homepage
- Thème adapté : bonheur pour login, feeling-happy pour signup, message pour reset password
**Mapping final :**
- `undraw_happy_fsrv.svg` → `auth-login.svg` → Login sidebar
- `undraw_feeling_happy_63z9.svg` → `auth-signup.svg` → Sign up sidebar
- `undraw_message-sent_iyz6.svg` → `auth-message.svg` → Forgot password / Confirmation / Unlock
**Note :** `hero-illustration.svg` initialement prévu pour signup, remplacé par `feeling-happy` car déjà utilisé sur la homepage.

---

## Décision 010 — Design System documenté dans `.opencode/design/`

**Date :** 2026-06-02 (session DEVISE)
**Décision :** Centraliser le design system et les décisions dans `.opencode/design/` (hors du repo principal).
**Raison :**
- `DESIGN_SYSTEM.md` : référence exhaustive pour les agents IA
- `DECISIONS.md` : historique des choix, pourquoi on a fait comme ça
- Évite que les agents IA inventent des styles incohérents
- Facilite l'onboarding de nouveaux développeurs (humains ou IA)
- Situé dans `.opencode/` car c'est un méta-document (outillage, pas code applicatif)

---

## Décision 011 — Formulaires : Bootstrap natif, pas de surcharge CSS

**Date :** 2026-06-02 (session DEVISE)
**Décision :** Utiliser les styles Bootstrap 5.3 natifs pour tous les formulaires, sans CSS custom additionnel.
**Raison :**
- Simple Form est déjà configuré avec `--bootstrap` (tous les wrappers natifs)
- Bootstrap 5.3 a déjà un bon design de formulaire
- Éviter les conflits entre CSS custom et Bootstrap
- Moins de code = moins de maintenance
- Le focus ring utilise déjà `$primary` = `$teal` (via les variables Bootstrap)
**Exception :** Le layout (centrage, fond, carte) est stylé, mais pas les inputs eux-mêmes.

---

## Décision 012 — Correction SVG `hero-illustration.svg` : ajout width/height explicites

**Date :** 2026-06-02 (session DEVISE)
**Contexte :** L'image SVG affichait 0×0 px dans le sidebar auth malgré un statut HTTP 200.
**Cause racine :** Le SVG n'avait que `viewBox`, pas d'attributs `width`/`height`. Le navigateur ne pouvait pas calculer la taille intrinsèque → `img-fluid` avec `height: auto` donnait 0px.
**Décision :** Ajouter `width="500" height="400"` sur l'élément `<svg>`.
**Impact :** Aucun sur la homepage (le SVG y est déjà contraint par son conteneur). Corrige l'affichage dans le sidebar.
**Leçon :** Toujours mettre `width`/`height` sur les SVG utilisés via `image_tag`.

---

## Décision 013 — Correction layout flex sidebar : `flex: 0 0 440px` sur la carte

**Date :** 2026-06-02 (session DEVISE)
**Contexte :** Le sidebar auth ne recevait aucun espace (0px), l'image restait invisible.
**Cause racine :** `.auth-card` avait `width: 100%` (mobile-first) non écrasé sur desktop. Dans le flex container avec `gap: 4rem`, la carte monopolisait tout l'espace → le sidebar avec `flex: 1 1 0%` restait à 0.
**Première tentative :** `width: auto` + `max-width: 440px` — n'a pas fonctionné car le navigateur attribuait quand même tout au flex-basis.
**Solution finale :** `flex: 0 0 440px` sur `.auth-card` (taille fixe, ne grandit pas, ne rétrécit pas) + `flex: 1 1 auto` sur `.auth-sidebar` (démarre à la taille du contenu puis grandit).
**Leçon :** Dans un conteneur flex avec `gap`, toujours utiliser `flex-basis` explicite plutôt que `width` + `max-width`.

---

## Décision 014 — Correction validation email : `uniqueness { scope: :password }` → `uniqueness: true`

**Date :** 2026-06-02 (session DEVISE)
**Contexte :** `ActiveRecord::StatementInvalid` au `create` Devise : `PG::UndefinedColumn: column users.password does not exist`.
**Cause racine :** `validates :email, uniqueness: { scope: :password }` — Devise n'a pas de colonne `password` (attribut virtuel), la colonne réelle est `encrypted_password`. La validation générait `WHERE "users"."password" = ...`.
**Décision :** Remplacer par `validates :email, uniqueness: true`. Devise (`validatable`) inclut déjà cette validation, donc elle est techniquement redondante mais inoffensive et explicite.
**Leçon :** Ne jamais scoper l'unicité d'un email par un attribut virtuel Devise (`password`, `password_confirmation`).

---

## Décision 015 — Migration `first_name`/`last_name` manquante

**Date :** 2026-06-02 (session DEVISE)
**Contexte :** `NoMethodError: undefined method 'first_name'` sur le formulaire d'inscription.
**Cause racine :** Le modèle `User` validait `first_name` et `last_name` mais les colonnes n'existaient pas en base. La migration n'avait jamais été générée.
**Décision :** Générer et exécuter `AddFirstNameAndLastNameToUsers`.
**Leçon :** Vérifier `db/schema.rb` avant d'ajouter des champs à un formulaire — le modèle peut déclarer des validations sans que les colonnes existent.

---

## Décision 016 — Lien navbar « Paramètres » → `edit_user_registration_path`

**Date :** 2026-06-02 (session DEVISE)
**Contexte :** Le dropdown « Paramètres » pointait vers `"#"`.
**Décision :** Pointer vers `edit_user_registration_path` (page de modification de profil Devise).
**Note :** Le lien « Mon espace » reste un placeholder `"#"` — à implémenter quand le dashboard existera.

---

## Décision 017 — Règle : commentaires SCSS = `//`, pas `<%# %>`

**Date :** 2026-06-02 (session DEVISE)
**Contexte :** `SassC::SyntaxError` car les fichiers SCSS contenaient des commentaires ERB.
**Cause :** Erreur humaine — les commentaires `<%# %>` sont valides uniquement dans les fichiers `.erb`, pas `.scss`.
**Décision :** Utiliser `//` (mono-ligne) ou `/* */` (bloc) dans tous les fichiers SCSS.
**Leçon :** Vérifier le type de fichier avant d'écrire des commentaires.

---

## Décision 018 — Page FAQ : layout sidebar + accordéon

**Date :** 2026-06-02 (session FAQ)
**Décision :** Page `/faq` publique avec sidebar gauche sticky (navigation par catégorie) + contenu à droite (accordéon Bootstrap Collapse).
**Raison :**
- Cohérent avec le design system MindSnap (teal, Nunito/Work Sans, border-radius)
- Sidebar = navigation rapide entre catégories, contenu = accordéon pour ne pas submerger
- Accessible sans connexion (page publique)
**Technique :** Bootstrap Collapse natif (pas de JS custom pour l'accordéon), Stimulus pour la recherche et le ScrollSpy.
**Fichier contenant le texte :** `app/views/faqs/index.html.erb` (tout le contenu Q&A est inline, pas en base de données).

---

## Décision 019 — FAQ : 20 questions en 5 catégories

**Date :** 2026-06-02 (session FAQ)
**Décision :** 20 questions réparties en 5 catégories de 4 questions.
**Catégories et icônes FA6 :**
- Général (`fa-circle-question`)
- Compte & Sécurité (`fa-lock`)
- Documents (`fa-file-lines`)
- IA & Recherche (`fa-robot`)
- Offres & Prix (`fa-tag`)
**Modification du texte :** éditer `app/views/faqs/index.html.erb`, repérer les `<%= render "shared/faq_item" %>` et modifier les paramètres `question:` et `answer:`. Le HTML est autorisé dans `answer:` (balises `<strong>`, `<em>`).

---

## Décision 020 — FAQ : recherche Stimulus + IntersectionObserver

**Date :** 2026-06-02 (session FAQ)
**Décision :** Un seul contrôleur Stimulus `faq-search` gère à la fois la recherche (filtrage temps réel) et le ScrollSpy (surlignage sidebar au scroll).
**Raison :** Éviter deux contrôleurs séparés pour une page simple. IntersectionObserver est natif (pas de dépendance). Le scroll smooth au clic gère le décalage de la navbar sticky (72px).
**Fichier :** `app/javascript/controllers/faq_search_controller.js`
**À savoir :** le `data-faq-search-words-value` sur chaque `.faq-item` contient le texte de la question en minuscules sans ponctuation — c'est la clé de filtrage. Si tu modifies une question dans la vue, le filtrage continue de fonctionner automatiquement.

---

## 📁 Où modifier le texte de la FAQ

**Un seul fichier à éditer :** `app/views/faqs/index.html.erb`

Chaque question est un bloc comme celui-ci :
```erb
<%= render "shared/faq_item",
      id: "q1",
      question: "MindSnap, c'est quoi exactement ?",
      answer: "MindSnap est ton <strong>deuxième cerveau</strong>..." %>
```

Pour **ajouter une question** : copier un bloc existant, changer `id:` (unique !), `question:` et `answer:`.
Pour **modifier une réponse** : éditer le `answer:` (HTML autorisé).
Pour **changer une catégorie** : modifier le `<h2 class="faq-category">` correspondant et l'icône `<i>`.

**Si tu ajoutes une 6ᵉ catégorie**, il faut aussi :
1. Ajouter un `<section id="category-nouveau">` dans la vue
2. Ajouter un `<a href="#category-nouveau">` dans le sidebar

---

## Décision 021 — Navbar : dropdown "Fonctionnalités" remplace liens simples

**Date :** 2026-06-02 (session NAVBAR)
**Décision :** Remplacer les liens simples "Fonctionnalités" et "Comment ça marche" par un dropdown "Fonctionnalités" avec icônes Font Awesome et séparateurs.
**Contenu du dropdown :**
- Section "Gestion" → Mes documents (`documents_path`), Mes dossiers (`folders_path`)
- Section "Intelligence" → Discuter avec l'IA (`conversations_path`)
**Raison :** "Comment ça marche" faisait doublon avec la homepage. Le dropdown regroupe les features accessibles après connexion, avec des icônes pour la lisibilité.
**Fichiers modifiés :** `app/views/shared/_navbar.html.erb`, `app/assets/stylesheets/components/_navbar.scss` (dropdown-header teal).
**Accessibilité :** `role="button"`, `aria-expanded`, `aria-labelledby` sur le dropdown. Navigation clavier gérée par Bootstrap JS.

---

*Ce fichier doit être mis à jour à chaque nouvelle décision de design. Format : date, contexte, décision, raison, alternatives rejetées.*

---

## Décision 022 — Résumé IA : affichage conditionnel + partial + polling

**Date :** 2026-06-04
**Contexte :** Le résumé IA était un placeholder en dur dans `show.html.erb`, jamais affiché même quand généré.
**Décision :** Remplacer par `render "documents/summary"` avec condition `document.summary.present?`. Ajouter un partial `_summary.html.erb` réutilisable avec `id="doc-summary"`. Polling Stimulus toutes les 3s vers `/summary_status` (max 60s).
**Fichiers :** `app/views/documents/_summary.html.erb` (NOUVEAU), `app/javascript/controllers/summary_poll_controller.js` (NOUVEAU).

## Décision 023 — Bouton "Régénérer" visible si fichier attaché

**Date :** 2026-06-04
**Contexte :** Le bouton "Régénérer" était masqué quand `content` vide. Or les fichiers uploadés n'ont pas de contenu tant que l'extraction n'a pas eu lieu.
**Décision :** Condition `document.content.present? || document.file.attached?`. L'action `summarize` lance `ExtractTextJob` si contenu vide + fichier attaché.
**Raison :** L'utilisateur doit pouvoir initier le pipeline (extraction → embedding → résumé) depuis la page show.

## Décision 024 — Tags IA affichés sous le résumé

**Date :** 2026-06-04
**Contexte :** `TagDocumentJob` générait les tags mais ils n'étaient jamais affichés dans `show.html.erb`.
**Décision :** Ajouter une section badges sous le résumé IA (`<% @document.tags.each %>`).
**Fichier :** `app/views/documents/show.html.erb`.
