Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :users, only: %i[create show]
      namespace :auth do
        post 'verify', to: 'verify#create'
      end
    end
  end
end
