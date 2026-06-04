# ============================================================
# FaqsController — page FAQ publique
# Accessible sans connexion (skip authenticate_user!).
# Cf. .opencode/design/DECISIONS.md (section FAQ à venir)
# ============================================================
class FaqsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    # Les questions/réponses sont définies directement dans la vue
    # via des data attributes pour le filtrage Stimulus.
    # Aucune donnée DB nécessaire — page statique.
  end
end
