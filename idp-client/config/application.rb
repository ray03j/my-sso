require_relative 'boot'
require 'rails/all'

module IdpClient
  class Application < Rails::Application
    config.load_defaults 8.0
    config.api_only = true
    config.time_zone = 'Tokyo'
  end
end
