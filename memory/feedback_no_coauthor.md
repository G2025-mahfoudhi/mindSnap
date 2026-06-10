---
name: feedback-no-coauthor
description: Ne jamais ajouter Co-Authored-By dans les commits — ça affiche Claude comme collaborateur GitHub
metadata:
  type: feedback
---

Ne jamais ajouter `Co-Authored-By: Claude ...` dans les messages de commit.

**Why:** GitHub affiche les co-auteurs comme des contributeurs du projet, ce qui fait apparaître Claude dans la liste des collaborateurs du dépôt — indésirable pour l'équipe.

**How to apply:** Tous les commits doivent avoir un message propre sans aucune ligne `Co-Authored-By`.
