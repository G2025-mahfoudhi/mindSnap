Rails.application.routes.draw do
  mount MissionControl::Jobs::Engine, at: "/jobs" if defined?(MissionControl::Jobs)

  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }
  resource :avatar, only: [:destroy]
  resource :plan, only: [:update]
  root to: "pages#home"
  get "dashboard", to: "dashboard#index"

  resources :espaces, only: [:index]

  resources :documents do
    member do
      get :download
      get :summary_status
      get :chat
      post :summarize
      delete :reset_chat
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

  get "equipe", to: "pages#equipe"
  get "faq", to: "faqs#index"
  get "search", to: "searches#index"
  post "tts/speak", to: "tts#speak"
  post "transcribe", to: "transcriptions#create"
  get "up" => "rails/health#show", as: :rails_health_check



end
