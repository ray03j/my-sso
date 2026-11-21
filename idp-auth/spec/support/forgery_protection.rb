# テスト環境では CSRF の検証を無効にしている。
# CSRF トークンの有無で挙動が変わることを確かめるテストには :forgery_protection を付け、検証を有効にする
RSpec.configure do |config|
  config.around(:each, :forgery_protection) do |example|
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
