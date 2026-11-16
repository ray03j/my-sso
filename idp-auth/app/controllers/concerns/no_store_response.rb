# トークンなど機密情報を含むレスポンスを、プロキシやブラウザにキャッシュさせない。
# エラー応答も含めて全レスポンスに付けるため before_action で設定する。
module NoStoreResponse
  extend ActiveSupport::Concern

  included do
    before_action :prevent_caching
  end

  private

  def prevent_caching
    no_store
    response.headers['Pragma'] = 'no-cache'
  end
end
