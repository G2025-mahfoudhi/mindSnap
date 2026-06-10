# ============================================================
# ApplicationController — contrôleur de base pour toute l'app.
#
# Trois responsabilités :
# 1. Authentification globale (Devise) — tout est protégé sauf home
# 2. Layout adaptatif : layout "devise" pour les pages d'auth,
#    layout "application" (navbar + footer) pour le reste.
#    Cf. .opencode/design/DECISIONS.md #005
# 3. Strong Parameters Devise : autorise first_name et last_name
#    dans les formulaires d'inscription et d'édition de profil.
#    Cf. .opencode/design/DECISIONS.md #008
# ============================================================
class ApplicationController < ActionController::Base
  # Authentification Devise : toutes les pages nécessitent
  # d'être connecté, sauf la homepage (skip dans PagesController).
  before_action :authenticate_user!

  # Strong Parameters Devise : autorise les champs supplémentaires
  # first_name et last_name pour sign_up et account_update.
  # Sans ça, Devise les ignore (whitelist de sécurité).
  before_action :configure_permitted_parameters, if: :devise_controller?

  # Layout adaptatif : sur les contrôleurs Devise, on utilise
  # le layout épuré "devise" (pas de navbar/footer).
  # Sur tous les autres, le layout "application" standard.
  # devise_controller? est fourni par Devise.
  layout :layout_by_resource

  private

  # Retourne le layout à utiliser selon le contrôleur courant.
  # devise_controller? retourne true uniquement pour les contrôleurs
  # gérés par Devise (sessions, registrations, passwords,
  # confirmations, unlocks).
  def layout_by_resource
    if devise_controller?
      "devise"      # app/views/layouts/devise.html.erb — épuré
    else
      "application" # app/views/layouts/application.html.erb — navbar + footer
    end
  end

  # Autorise les paramètres supplémentaires pour Devise.
  # Appelé automatiquement avant chaque action Devise
  # grâce au before_action :configure_permitted_parameters.
  def configure_permitted_parameters
    # Champs autorisés à l'inscription (sign_up)
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[first_name last_name avatar])

    # Champs autorisés à la modification du profil (account_update)
    devise_parameter_sanitizer.permit(:account_update, keys: %i[first_name last_name avatar])
  end
end
