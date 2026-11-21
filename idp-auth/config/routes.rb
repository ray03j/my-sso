Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      namespace :auth do
        resource :session, only: %i[create destroy], controller: 'session'
      end
      resource :consent, only: %i[create], controller: 'consent'
    end
  end

  # 認可エンドポイントは GET と POST の両方に対応しなければならない（OIDC Core §3.1.2.1）
  get '/authorize', to: 'authorize#show'
  post '/authorize', to: 'authorize#show'
  post '/token', to: 'tokens#create'
  post '/revoke', to: 'revocations#create'
  get '/.well-known/openid-configuration', to: 'discovery#show'
  get '/jwks.json', to: 'jwks#show'
  # UserInfo は GET と POST の両方に対応しなければならない（OIDC Core §5.3）
  get '/userinfo', to: 'userinfo#show'
  post '/userinfo', to: 'userinfo#show'
end
