class AvatarsController < ApplicationController
  def destroy
    current_user.avatar.purge
    redirect_to edit_user_registration_path, notice: "Photo de profil supprimée."
  end
end
