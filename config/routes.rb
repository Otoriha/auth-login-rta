Rails.application.routes.draw do
  get "home/index"
  get "users/show"
  get "users/edit"
  get "users/update"
  get "users/destroy"
  get "rankings/index"
  get "providers/index"
  get "sessions/create"
  get "sessions/destroy"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # ログイン関連
  get "login" => "sessions#new", as: :login
  delete "logout" => "sessions#destroy", as: :logout

  # OmniAuth関連
  get "auth/:provider/callback" => "omniauth_callbacks#callback"
  get "auth/failure" => "omniauth_callbacks#failure"
  get "auth_flow" => "auth_flow#start", as: :auth_flow
  get "auth_flow/github" => "auth_flow#github", as: :auth_flow_github
  get "auth_flow/twitter" => "auth_flow#twitter", as: :auth_flow_twitter
  get "auth_flow/google" => "auth_flow#google", as: :auth_flow_google
  get "auth_flow/complete" => "auth_flow#complete", as: :auth_flow_complete

  # ルートパス
  root "rankings#index"
end
