module Api
  module V1
    class ClientsController < ApplicationController
      before_action :require_internal_api_key

      def index
        render json: { clients: Client.all.map { |client| client_response(client) } }
      end

      def show
        client = Client.find_by(client_id: params[:id])
        return head :not_found unless client

        render json: client_response(client)
      end

      def create
        client = Client.new(client_params)
        client.client_id = SecureRandom.uuid
        client.client_secret = SecureRandom.urlsafe_base64(32)

        if client.save
          render json: client_response(client).merge(client_secret: client.client_secret), status: :created
        else
          render json: { errors: client.errors.full_messages }, status: :unprocessable_content
        end
      end

      private

      def client_params
        params.require(:client).permit(:name, redirect_uris: [], allowed_scopes: [])
      end

      def client_response(client)
        {
          client_id: client.client_id,
          name: client.name,
          redirect_uris: client.redirect_uris,
          allowed_scopes: client.allowed_scopes,
          created_at: client.created_at,
          updated_at: client.updated_at
        }
      end
    end
  end
end
