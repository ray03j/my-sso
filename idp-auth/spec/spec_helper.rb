ENV['RAILS_ENV'] ||= 'test'
ENV['INTERNAL_API_KEY'] ||= 'test-internal-api-key'
ENV['JWT_SECRET'] ||= 'test-jwt-secret'
ENV['IDP_CLIENT_URL'] ||= 'http://idp-client:3000'
ENV['IDP_USER_VERIFY_URL'] ||= 'http://idp-user:3001/api/v1/auth/verify'
require_relative '../config/environment'

abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'
require 'factory_bot_rails'
require 'webmock/rspec'
require 'httparty'
require 'support/request_helpers'

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include RequestHelpers, type: :request
end
