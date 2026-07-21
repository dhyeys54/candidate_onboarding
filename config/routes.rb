require "sidekiq/web"

Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
  configured_username = ENV.fetch("SIDEKIQ_WEB_USERNAME", nil)
  configured_password = ENV.fetch("SIDEKIQ_WEB_PASSWORD", nil)

  configured_username.present? && configured_password.present? &&
    ActiveSupport::SecurityUtils.secure_compare(username, configured_username) &&
    ActiveSupport::SecurityUtils.secure_compare(password, configured_password)
end

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  mount Sidekiq::Web, at: "/sidekiq"

  # Onboarding namespace: candidate-facing CV upload/parse/review flow (the core product surface).
  namespace :onboarding do
    resources :candidates, only: [ :index, :create ]
    resources :candidate_profiles, only: [ :show, :edit, :update ] do
      resource :cv, only: [ :show ], controller: "candidate_documents"
    end
  end

  # Admin namespace: staff-only, HTTP Basic Auth via Admin::BaseController (ADMIN_USERNAME/ADMIN_PASSWORD).
  namespace :admin do
    resources :candidates, only: [ :index, :show ] do
      resource :cv, only: [ :show ], controller: "candidate_documents"
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Candidates land here first to upload their CV.
  root "onboarding/candidates#index"
end
