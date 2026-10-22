require_relative 'boot'
require 'rails/all'

module IdpAuth
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = false
    config.time_zone = 'Tokyo'
    config.autoload_lib(ignore: %w[assets tasks])

    config.session_store :cookie_store,
                         key: '_idp_auth_session',
                         httponly: true,
                         secure: Rails.env.production?,
                         same_site: :lax,
                         expire_after: 1.day
  end
end
