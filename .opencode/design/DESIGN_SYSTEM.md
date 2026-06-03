# 🎨 Design System — MindSnap

> **Version :** 1.0.0 | **Dernière mise à jour :** 2026-06-02
>
> Document de référence unique pour tout le front-end du projet.
> Tout agent IA ou développeur doit consulter ce fichier avant de produire du HTML/CSS/ERB.

---

## 1. Identité

| Propriété | Valeur |
|---|---|
| **Nom** | MindSnap |
| **Baseline** | « Ton deuxième cerveau » |
| **Ton** | Inspiré Notion — clean, direct, sans jargon technique |
| **Cible** | Grand public |
| **Slogans secondaires** | « Capture tes idées, tes cours, tes documents. Retrouve-les instantanément grâce à l'IA. » |

---

## 2. Palette de couleurs

### Couleurs principales

| Usage | Variable SCSS | Code | Aperçu |
|---|---|---|---|
| **Accent principal** | `$teal` | `#549695` | Teal |
| **Accent foncé** (footer, navbar-dark) | `$teal-dark` | `#2A4B4B` | Dark teal |
| **Accent hover** | `$teal-hover` | `darken($teal, 8%)` / `#468280` | — |
| **Accent light** (fond icônes) | `$teal-light` | `lighten($teal, 35%)` / `#D6EDED` | — |
| **Fond sections alternées** | `$warm-gray` | `#F7F5F4` | Gris chaud |
| **Texte principal** | `$near-black` | `#1A1A1A` | Presque noir |
| **Fond principal** | `$white` | `#FFFFFF` | Blanc |

### Couleurs sémantiques (Bootstrap)

| Usage | Variable SCSS | Code | Mapping Bootstrap |
|---|---|---|---|
| Primaire | `$primary` | `#549695` (teal) | `.btn-primary`, `.text-primary` |
| Succès | `$success` | `#1EDD88` | `.alert-success` |
| Info | `$info` | `#FFC65A` | `.alert-info` |
| Danger | `$danger` | `#FD1015` | `.btn-danger`, `.alert-danger` |
| Warning | `$warning` | `#E67E22` | `.alert-warning` |

### Usage couleur par type d'élément

| Élément | Fond | Texte | Bordure |
|---|---|---|---|
| Page standard | `$white` | `$near-black` | — |
| Page auth | `$warm-gray` | `$near-black` | — |
| Carte | `$white` | `$near-black` | ombre uniquement |
| Bouton primaire | `$teal` | `$white` | `$teal` |
| Bouton outline | transparent | `$teal` | `$teal` |
| Bouton danger | `$danger` | `$white` | — |
| Navbar | `$white` | `$near-black` | `box-shadow` subtil |
| Footer | `$teal-dark` | `rgba(255,255,255,0.8)` | — |
| Input focus | `$white` | `$near-black` | `$teal` (3px ring) |
| Erreur | `$danger` (fond clair) | `$danger` | `$danger` |

### Contrastes minimums (a11y)

- Texte sur fond blanc : ratio ≥ 4.5:1 → `$near-black` OK
- Teal sur blanc : ratio ≥ 3:1 (large text) → OK pour titres, pas pour body text
- Ne **jamais** utiliser `$teal` comme couleur de body text sur fond blanc

---

## 3. Typographie

| Propriété | Valeur |
|---|---|
| **Font titres** | `"Nunito", "Helvetica", sans-serif` → `$headers-font` |
| **Font corps** | `"Work Sans", "Helvetica", sans-serif"` → `$body-font` |
| **Source** | Google Fonts (`@import` dans `config/_fonts.scss`) |
| **Base** | `1rem` (16px) |

### Échelle de tailles

| Élément | Taille | Technique |
|---|---|---|
| `h1` hero | `clamp(2rem, 5vw, 3.5rem)` / 800 | `.hero__title` |
| `h2` section | `clamp(1.5rem, 4vw, 2.25rem)` / 700 | `.features__title` |
| `h3` carte | `1.125rem` / 700 | `.feature-card__title` |
| Body standard | `1rem` (16px) / 400 | — |
| Body large | `1.125rem` / 400 | `.hero__subtitle` |
| Small / hint | `0.9375rem` | `.feature-card__text` |
| Label | `0.875rem` / 500 | `.form-label` |
| Footer | `0.9375rem` (corps), `0.8125rem` (bas) | `.footer` |

### Interlignage (line-height)

- Titres : `1.15` à `1.2`
- Corps : `1.6` à `1.7`
- Inputs/hints : `1.6`

---

## 4. Grille & Breakpoints

**Système :** Bootstrap 5.3 grid, **mobile-first** obligatoire.

| Breakpoint | Min-width | Classe Bootstrap |
|---|---|---|
| X-Small | < 576px | `.col-*` |
| Small | ≥ 576px | `.col-sm-*` |
| Medium | ≥ 768px | `.col-md-*` |
| Large | ≥ 992px | `.col-lg-*` |
| Extra large | ≥ 1200px | `.col-xl-*` |
| Extra extra large | ≥ 1400px | `.col-xxl-*` |

### Règles de grille

- Structure : `container > row > col-*`
- Gouttières par défaut (gap via `g-4` etc.)
- Largeur max contenu : 1140px (container Bootstrap par défaut)
- Largeur max carte auth : 440px
- Largeur max carte standard : pas de max-width explicite (flexible)

---

## 5. Espacements

### Échelle

| Token | Valeur | Usage typique |
|---|---|---|
| `xs` | `0.25rem` (4px) | Icônes inline gap |
| `sm` | `0.5rem` (8px) | Gap boutons |
| `md` | `1rem` (16px) | Padding cartes, gap paragraphes |
| `lg` | `1.5rem` (24px) | Padding cartes larges, gap sections |
| `xl` | `2rem` (32px) | Marges headings |
| `2xl` | `3rem` (48px) | Section header → content |
| `3xl` | `4rem` (64px) | Section bottom padding |
| `4xl` | `5rem` (80px) | Section vertical padding (standard) |

### Règles d'espacement

- Sections : `padding: 5rem 0` (mobile), `6rem 0` (desktop)
- Cartes : `padding: 2rem 1.5rem` (feature), `2.5rem` (auth desktop), `1.5rem` (auth mobile)
- Boutons : gap `0.75rem` entre boutons côte à côte

---

## 6. Border Radius

| Variable SCSS | Valeur | Usage |
|---|---|---|
| `$border-radius-sm` | `0.25rem` | Petits badges, toasts |
| `$border-radius` | **`0.5rem`** | Boutons, inputs, icônes |
| `$border-radius-lg` | `0.75rem` | Cartes (feature, auth) |
| `$border-radius-xl` | `1rem` | Cartes larges |
| `$border-radius-xxl` | `2rem` | Pills, avatars |

---

## 7. Ombres

3 niveaux seulement. Éviter les ombres inutiles.

| Niveau | Code | Usage |
|---|---|---|
| **Subtil** | `0 4px 24px rgba(0, 0, 0, .06)` | Cartes (hover), cartes auth |
| **Moyen** | `0 1px 0 rgba(0,0,0,.06)` | Navbar (bottom separator) |
| **Fort** | *(non défini — à réserver pour modales)* | |

---

## 8. Composants

### 8.1 Boutons

| Variante | Classe | Fond | Texte |
|---|---|---|---|
| **Primaire** | `.btn.btn-primary` | `$teal` | blanc |
| **Outline** | `.btn.btn-outline-secondary` | transparent | hérite |
| **Danger** | `.btn.btn-danger` | `$red` | blanc |
| **Danger outline** | `.btn.btn-outline-danger` | transparent | `$red` |
| **Lien** | `.btn.btn-link` | transparent | `$teal` |

**Tailles :**
- Par défaut : `.btn` (hauteur implicite via padding)
- Large : `.btn-lg.px-4` pour CTA hero
- Small : `.btn-sm.px-3` pour navbar

**États :**
- `:hover` : assombrir de 8% (géré par Bootstrap `darken()`)
- `:focus` : `box-shadow: 0 0 0 0.25rem rgba($teal, .25)`
- `:disabled` : `opacity: 0.65`

**Full-width :** `.w-100` pour boutons de formulaire auth.

### 8.2 Inputs (formulaires)

Tous les inputs utilisent le wrapper Simple Form Bootstrap 5 natif (déjà configuré dans `config/initializers/simple_form_bootstrap.rb`).

| Élément | Classe CSS | Source |
|---|---|---|
| Input text/email/password | `.form-control` | Simple Form wrapper → Bootstrap |
| Label | `.form-label` | Simple Form wrapper → Bootstrap |
| Select | `.form-select` | Simple Form wrapper vertical |
| Checkbox | `.form-check-input` + `.form-check` | Simple Form wrapper boolean |
| Erreur inline | `.is-invalid` + `.invalid-feedback` | Simple Form |
| Erreur globale | `.alert.alert-danger` | `f.error_notification` |
| Hint | `.form-text` | Simple Form wrapper |
| Wrapper | `.mb-3` | Simple Form wrapper → espacement vertical |

**Ne pas** surcharger les styles Bootstrap des inputs sauf pour le focus ring (déjà géré par Bootstrap qui utilise `$primary` = `$teal`).

### 8.3 Cartes

**Carte feature** (homepage) :

```scss
.feature-card {
  background: $white;
  border-radius: $border-radius-lg; // 0.75rem
  padding: 2rem 1.5rem;
  height: 100%; // égalise les hauteurs dans une row

  &:hover {
    box-shadow: 0 4px 24px rgba(0, 0, 0, .06);
    transform: translateY(-2px);
  }
}
```

**Carte auth** (pages Devise) :

```scss
.auth-card {
  background: $white;
  border-radius: $border-radius-lg; // 0.75rem
  padding: 2.5rem; // desktop, 1.5rem mobile
  box-shadow: 0 4px 24px rgba(0, 0, 0, .06);
  max-width: 440px;
  width: 100%;
}
```

### 8.4 Icônes

**Cercle icône** (features, avantages) :

```scss
.icon-circle {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 48px;
  height: 48px;
  border-radius: $border-radius; // 0.5rem
  background: $teal-light; // #D6EDED
  color: $teal;
  font-size: 1.25rem;
}
```

**Library :** Font Awesome 6 Free (classes `fa-solid fa-*`).

### 8.5 Navbar

```scss
.navbar {
  box-shadow: 0 1px 0 rgba(0, 0, 0, .06); // séparateur subtil
  // Sticky top, fond blanc, expand sur md
}
```

- **Brand** : logo 32×32 + texte "MindSnap" bold
- **Liens desktop** : `.nav-link`, font-weight 500
- **CTA** : `.btn.btn-primary.btn-sm.px-3`
- **Avatar dropdown** : image ronde 36×36
- **Mobile** : toggler standard

### 8.6 Footer

```scss
.footer {
  background: $teal-dark;
  color: rgba($white, .8);
  padding: 4rem 0 2rem;
}
```

- 4 colonnes desktop : Brand (5/12) + 3 colonnes liens (2/12 chacune)
- Liens : `rgba(white, .65)`, hover → `white`
- Bottom bar : bordure subtile, copyright centré

### 8.7 Flash messages

```scss
.alert {
  position: fixed;
  bottom: 16px;
  right: 16px;
  z-index: 1000;
}
```

- Alert Bootstrap standard, dismissible
- `notice` → `alert-info`
- `alert` → `alert-warning`

### 8.8 Auth Card (pages Devise)

Layout desktop 2 colonnes dans un conteneur flex centré :

```
┌───────────────────────────────────────────────┐
│               [Logo MindSnap]                  │
│                                                │
│   ┌─────────────────┐   ┌──────────────────┐  │
│   │                 │   │                  │  │
│   │   .auth-card    │   │  .auth-sidebar   │  │
│   │   (formulaire)  │   │  illustration    │  │
│   │                 │   │  + citation      │  │
│   │                 │   │                  │  │
│   └─────────────────┘   └──────────────────┘  │
│                                                │
└───────────────────────────────────────────────┘
```

Mobile : `.auth-sidebar` masquée, carte seule centrée.

**Fond page :** `$warm-gray` (règle : toute page auth a un fond `$warm-gray`).

---

## 9. Templates de page

### 9.1 Homepage

- Layout : `application` (navbar + footer)
- Fond : alterné blanc / warm-gray / blanc
- Sections : Hero → Features → How it works → Footer

### 9.2 Pages d'authentification (Devise)

- Layout : `devise` (pas de navbar, pas de footer)
- Fond : `$warm-gray`
- Structure : container centré verticalement (`min-height: 100vh`)
- Logo cliquable → `root_path`

### 9.3 Dashboard (à venir — après connexion)

- Layout : `application` (navbar connecté + footer)
- Fond : `$warm-gray` ou `$white` selon section

### 9.4 FAQ

- Layout : `application` (navbar + footer)
- Accessible sans connexion (publique)
- Structure : sidebar sticky (260px) + contenu accordéon
- Accordéon : Bootstrap Collapse natif, une réponse à la fois
- Recherche : Stimulus `faq-search`, filtrage temps réel
- ScrollSpy : IntersectionObserver, surligne la catégorie active dans le sidebar

---

## 10. Accessibilité (a11y)

### Checklist minimale

- [ ] HTML sémantique : `<nav>`, `<main>`, `<section>`, `<article>`, `<header>`, `<footer>`
- [ ] Hiérarchie de titres logique (h1 → h2 → h3, pas de saut)
- [ ] Tout élément interactif accessible au clavier (`Tab`, `Enter`, `Escape`)
- [ ] `aria-label` sur les liens sans texte visible
- [ ] `alt` sur toutes les images
- [ ] Labels associés à chaque champ de formulaire (`<label for="...">`)
- [ ] Focus visible sur tous les éléments interactifs
- [ ] Contraste texte/fond ≥ 4.5:1 (body), ≥ 3:1 (large text)

### Pièges fréquents

| ❌ À éviter | ✅ Faire |
|---|---|
| `href="#"` | `href` valide ou `<button>` |
| `display: none` pour masquer sur mobile | Mobile-first : cacher via `d-none d-lg-block` |
| Pas de `:focus` style | Toujours définir `:focus-visible` |
| Couleur seule pour info | Icône + texte + couleur |
| Texte `$teal` sur fond blanc (body) | Réserver `$teal` aux accents, pas au body text |

---

## 11. Conventions de code

### SCSS

- **Organisation** : `config/` (variables), `components/` (composants), `pages/` (pages)
- **Nommage** : BEM-like → `.composant__element--modifier`
- **Pas de `!important`** (sauf cas extrême justifié)
- **Pas de sélecteurs > 3 niveaux** de profondeur
- **Mobile-first** systématique : styles de base = mobile, `@include media-breakpoint-up(md)` pour desktop

### ERB

- **Partials** : `shared/_nom.html.erb` pour composants globaux, `devise/shared/_nom.html.erb` pour Devise
- **Pas de logique métier** dans les vues
- **Commentaires ERB** : ` <%# commentaire %>` (ne génère pas de HTML)

### Images

- **Emplacement** : `app/assets/images/`
- **Formats** : SVG prioritaire, PNG pour logos
- **Utiliser `image_tag`** (helper Rails) toujours

---

## 12. Variables SCSS — index

Fichier de référence : `app/assets/stylesheets/config/_colors.scss`

```scss
// Palette MindSnap
$teal:          #549695;
$teal-dark:     #2A4B4B;
$warm-gray:     #F7F5F4;
$near-black:    #1A1A1A;
$white:         #FFFFFF;

// Accent shades
$teal-hover:    darken($teal, 8%);
$teal-light:    lighten($teal, 35%);
```

Fichier de référence : `app/assets/stylesheets/config/_bootstrap_variables.scss`

```scss
$body-bg:       $white;
$body-color:    $near-black;
$primary:       $teal;
$font-family-sans-serif: $body-font;
$headings-font-family:   $headers-font;
$border-radius: .5rem;
```

---

*Ce document est la source de vérité pour tout le design MindSnap. Toute modification visuelle doit être répercutée ici.*
