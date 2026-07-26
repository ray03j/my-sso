class ClientVerificationService
  def self.verify(client_id:, client_secret:, redirect_uri: nil)
    return { valid: false, error: 'client_id is required' } if client_id.blank?
    return { valid: false, error: 'client_secret is required' } if client_secret.blank?

    client = Client.find_by(client_id: client_id)
    return { valid: false, error: 'client not found' } unless client
    return { valid: false, error: 'invalid client_secret' } unless client.client_secret_valid?(client_secret)

    if redirect_uri.present? && client.redirect_uris.exclude?(redirect_uri)
      return { valid: false, error: 'invalid redirect_uri' }
    end

    { valid: true, client: client }
  end
end
