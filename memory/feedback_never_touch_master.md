---
name: feedback-never-touch-master
description: Always work on a feature branch, never commit or edit files directly on master
metadata:
  type: feedback
---

Never modify files directly on the `master` branch. Always switch to the appropriate feature branch first (e.g. `connexion`, or whatever branch the user is working on).

**Why:** The user explicitly corrected this — changes made on master had to be reverted and re-applied on `connexion`.

**How to apply:** Before editing any file, check `git branch --show-current`. If on `master`, ask the user which branch to use, or switch to the active feature branch. The current working branch for UI/auth work is `connexion`.
