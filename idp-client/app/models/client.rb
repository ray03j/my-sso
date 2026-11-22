require 'bcrypt'
require 'uri'

class Client < ApplicationRecord
  validates :client_id, presence: true, uniqueness: true
  validates :client_secret_hash, presence: true
  validates :name, presence: true
  validates :redirect_uris, presence: true
  validates :allowed_scopes, presence: true

  validate :redirect_uris_must_be_valid_urls
  validate :post_logout_redirect_uris_must_be_valid_urls
  validate :allowed_scopes_must_be_supported

  attr_reader :client_secret

  def client_secret=(value)
    return if value.blank?

    @client_secret = value
    cost = Rails.env.test? ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
    self.client_secret_hash = BCrypt::Password.create(value, cost: cost)
  end

  def client_secret_valid?(secret)
    return false if client_secret_hash.blank? || secret.blank?

    BCrypt::Password.new(client_secret_hash) == secret
  end

  def redirect_uris
    (super || '').tr("\r", "\n").lines.map(&:strip).compact_blank
  end

  def redirect_uris=(uris)
    super(uris.is_a?(Array) ? uris.join("\n") : uris.to_s)
  end

  def post_logout_redirect_uris
    (super || '').tr("\r", "\n").lines.map(&:strip).compact_blank
  end

  def post_logout_redirect_uris=(uris)
    super(uris.is_a?(Array) ? uris.join("\n") : uris.to_s)
  end

  def allowed_scopes
    (super || '').split.map(&:strip).compact_blank.uniq
  end

  def allowed_scopes=(scopes)
    super(scopes.is_a?(Array) ? scopes.join(' ') : scopes.to_s)
  end

  private

  def redirect_uris_must_be_valid_urls
    validate_urls(:redirect_uris)
  end

  def post_logout_redirect_uris_must_be_valid_urls
    validate_urls(:post_logout_redirect_uris)
  end

  def validate_urls(attribute)
    public_send(attribute).each do |uri|
      parsed = URI.parse(uri)
      valid = (parsed.is_a?(URI::HTTP) || parsed.is_a?(URI::HTTPS)) && parsed.host.present?
      errors.add(attribute, "#{uri} is not a valid URL") unless valid
    rescue URI::InvalidURIError
      errors.add(attribute, "#{uri} is not a valid URL")
    end
  end

  def allowed_scopes_must_be_supported
    supported = %w[openid profile email]
    invalid = allowed_scopes - supported
    errors.add(:allowed_scopes, "#{invalid.join(', ')} are not supported") if invalid.any?
  end
end
