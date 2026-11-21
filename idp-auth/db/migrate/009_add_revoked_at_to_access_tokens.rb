# /revoke（RFC 7009）で失効させた access_token を、署名の検証だけでは見分けられないため記録する
class AddRevokedAtToAccessTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :access_tokens, :revoked_at, :datetime
  end
end
