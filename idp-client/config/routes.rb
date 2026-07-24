Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :clients, only: %i[create index show]
      post 'clients/verify', to: 'verify#create'
    end
  end
end
