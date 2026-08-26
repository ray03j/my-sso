Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      namespace :auth do
        resource :session, only: %i[create destroy], controller: 'session'
      end
      resource :consent, only: %i[create], controller: 'consent'
    end
  end

  get '/authorize', to: 'authorize#show'
  post '/token', to: 'tokens#create'
  get '/.well-known/openid-configuration', to: 'discovery#show'
end
