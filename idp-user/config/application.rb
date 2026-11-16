require_relative 'boot'
require 'rails/all'

module IdpUser
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = true
    config.time_zone = 'Tokyo'
  end
end
