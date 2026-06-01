# MindSnap — Homepage Plan

## Vision produit
"Deuxième cerveau" — cloud de documents texte avec OCR et recherche IA.
Capture → Organise → Retrouve → Pense plus loin.

## Cible & ton
- **Cible** : Grand public
- **Ton** : Inspiré Notion — clean, direct, sans jargon technique
- **Style** : Moderne épuré avec touches de couleur

## Palette
| Usage | Code | Aperçu |
|---|---|---|
| Accent principal | `#549695` | Teal |
| Accent foncé | `#2A4B4B` | Dark teal |
| Background sections alternées | `#F7F5F4` | Gris chaud |
| Texte | `#1A1A1A` | Presque noir |
| Fond | `#FFFFFF` | Blanc |

## Sections de la homepage

### 1. Hero (bannière principale)
- Baseline : "Ton deuxième cerveau"
- Sous-texte : "Capture tes idées, tes cours, tes documents. Retrouve-les instantanément grâce à l'IA."
- CTA principal : "Commencer" / "Créer un compte"
- Illustration vectorielle (style Undraw) à droite

### 2. Features (grille 3 colonnes)
Sans jargon, langage grand public. 6 features avec icône Font Awesome :
- **Capture tes documents** — Prends une photo, l'OCR fait le reste
- **Stockage cloud sécurisé** — Accessible partout, tout le temps
- **Organisation intuitive** — Classe par dossiers, matières, projets
- **Recherche intelligente** — Trouve n'importe quel document en une seconde
- **Export facile** — PDF, Word, texte — partage comme tu veux
- **Pose des questions à tes docs** — L'IA comprend et répond

### 3. Comment ça marche (3 étapes)
Trois colonnes avec numéro + illustration :
1. **Capture** — Prends en photo ou importe ton document
2. **Organise** — Range dans le bon dossier automatiquement
3. **Retrouve** — L'IA indexe tout, recherche instantanée

### 4. Footer
- Logo + nom
- Liens : À propos, Fonctionnalités, Blog, Aide
- Mentions légales
- Copyright

## Spécifications techniques
- **Stack** : Rails 8.1.3, Bootstrap 5.3, Sprockets, Sass, Font Awesome 6
- **Devise** : déjà configuré (User model)
- **Routes** : `root "pages#home"` — skip authentication sur home
- **Illustrations** : SVGs libres de droit (Undraw style)

## Fichiers à modifier/créer

| Fichier | Action |
|---|---|
| `app/views/pages/home.html.erb` | Remplacer placeholder → homepage complète |
| `app/views/shared/_navbar.html.erb` | Adapter navbar (logo MindSnap, liens) |
| `app/views/shared/_footer.html.erb` | Créer footer |
| `app/views/layouts/application.html.erb` | Ajouter `render "shared/footer"` |
| `app/assets/stylesheets/config/_colors.scss` | Ajouter variables couleurs |
| `app/assets/stylesheets/pages/_home.scss` | Styles homepage |
| `app/assets/stylesheets/components/_hero.scss` | Hero section |
| `app/assets/stylesheets/components/_features.scss` | Features grid |
| `app/assets/stylesheets/components/_how_it_works.scss` | Steps section |
| `app/assets/stylesheets/components/_footer.scss` | Footer |
| `app/assets/stylesheets/components/_index.scss` | Importer nouveaux composants |

## MCP configurés
- **21st Dev** : @21st-dev/magic (prêt) — génération composants UI React
  - ⚠️ Génère du React/TS, il faudra adapter en HTML/ERB pour Rails


## Workflow session 2
1. Charger le MCP 21st Dev si disponible
2. Générer un premier jet de la homepage via 21st Dev
3. Adapter le code généré (React → ERB + Bootstrap)
4. Appliquer les couleurs et le style Notion
5. Raffiner ensemble
