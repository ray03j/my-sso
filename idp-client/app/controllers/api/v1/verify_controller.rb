module Api
  module V1
    class VerifyController < ApplicationController
      before_action :require_internal_api_key

      def create
        result = ClientVerificationService.verify(
          client_id: params[:client_id],
          client_secret: params[:client_secret],
          redirect_uri: params[:redirect_uri]
        )

        return render_unauthorized(result[:error]) unless result[:valid]

        render json: verify_response(result[:client])
      end

      private

      def render_unauthorized(error)
        render json: { valid: false, error: error }, status: :unauthorized
      end

      def verify_response(client)
        {
          valid: true,
          client_id: client.client_id,
          name: client.name,
          redirect_uris: client.redirect_uris,
          allowed_scopes: client.allowed_scopes
        }
      end
    end
  end
end
