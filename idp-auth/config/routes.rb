Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      namespace :auth do
        resource :session, only: %i[create destroy], controller: 'session'
      end
    end
  end

  get '/authorize', to: 'authorize#show'
end
