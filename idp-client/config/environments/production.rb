require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.server_timing = false
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?
  config.public_file_server.headers = { "Cache-Control" => "public, max-age=#{1.year.to_i}" }

  config.cache_store = :memory_store

  config.active_support.deprecation = :notify
  config.active_support.disallowed_deprecation = :log
  config.active_support.disallowed_deprecation_warnings = []

  config.active_record.migration_error = false
  config.active_support.report_deprecations = false
  config.force_ssl = true
end
