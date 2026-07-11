Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :users, only: [:create]
      namespace :auth do
        post 'verify', to: 'verify#create'
      end
    end
  end
end
