# RP-Initiated Logout で、ログアウト後に戻してよい URL を登録する（OpenID Connect RP-Initiated Logout 1.0 §3）
class AddPostLogoutRedirectUrisToClients < ActiveRecord::Migration[7.1]
  def change
    add_column :clients, :post_logout_redirect_uris, :text, null: false, default: ''
  end
end
