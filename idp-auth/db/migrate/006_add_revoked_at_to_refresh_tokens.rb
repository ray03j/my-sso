class AddRevokedAtToRefreshTokens < ActiveRecord::Migration[7.1]
  def change
    add_column :refresh_tokens, :revoked_at, :datetime
  end
end
