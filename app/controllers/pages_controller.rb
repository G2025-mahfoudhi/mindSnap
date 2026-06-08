class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home, :equipe]

  def home
  end

  def equipe
  end
end
