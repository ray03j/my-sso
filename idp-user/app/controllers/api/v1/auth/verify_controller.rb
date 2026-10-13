module Api
  module V1
    module Auth
      class VerifyController < ApplicationController
        before_action :require_internal_api_key

        def create
          user = User::AuthenticationService.authenticate(
            params[:email],
            params[:password]
          )

          if user
            render json: success_response(user), status: :ok
          else
            render json: { code: 'INVALID_CREDENTIALS' }, status: :unauthorized
          end
        end

        private

        def success_response(user)
          {
            user: {
              id: user.id,
              email: user.email,
              name: user.name
            }
          }
        end
      end
    end
  end
end
