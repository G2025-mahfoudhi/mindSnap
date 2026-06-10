class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home, :equipe, :fonctionnalites, :apropos, :confidentialite]

  def home
  end

  def equipe
  end

  def fonctionnalites
  end

  def apropos
  end

  def confidentialite
  end
end
