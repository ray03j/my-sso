module Api
  module V1
    # 同意画面に表示するため、/authorize が中断して保存したリクエストの RP 名と scope を返す
    class AuthorizationRequestController < ApplicationController
      def show
        return head :unauthorized unless authenticated?

        stored = session[:authorize_params]
        return head :not_found if stored.blank?

        client = ::Auth::ClientRegistryService.fetch(
          client_id: stored['client_id'], redirect_uri: stored['redirect_uri'], scope: stored['scope']
        )
        return head :not_found if client.nil?

        render json: { client_id: client['client_id'], client_name: client['name'], scope: stored['scope'] }
      end
    end
  end
end
