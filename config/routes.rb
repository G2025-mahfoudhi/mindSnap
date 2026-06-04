Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"

  resources :espaces, only: [:index]

  resources :documents do
    member do
      get :download
    end
    resources :conversations, only: [:create, :show] do
      resources :messages, only: [:create]
    end
  end

  resources :folders, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
    post :chat, on: :member
  end

  resources :conversations, only: [:create, :index, :show, :destroy] do
    resources :messages, only: [:create]
  end

  get "faq", to: "faqs#index"
  get "search", to: "searches#index"
  post "tts/speak", to: "tts#speak"
  post "transcribe", to: "transcriptions#create"
  get "up" => "rails/health#show", as: :rails_health_check
end