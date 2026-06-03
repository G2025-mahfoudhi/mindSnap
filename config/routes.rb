Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"

  resources :espaces, only: [:index]

  resources :documents do
    resources :conversations, only: [:create, :show] do
      resources :messages, only: [:create]
    end
  end

  resources :folders, only: [:index, :show, :new, :create, :edit, :update, :destroy]

  resources :conversations, only: [:new, :create, :index, :show, :destroy] do
    resources :messages, only: [:create]
  end

  get "faq", to: "faqs#index"
  get "up" => "rails/health#show", as: :rails_health_check
end