class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home, :equipe]

  def home
    redirect_to dashboard_path if user_signed_in?
  end

  def equipe
  end
end
