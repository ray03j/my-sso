module Api
  module V1
    module Auth
      class SessionController < ApplicationController
        def create
          user = ::Auth::SessionService.authenticate(
            params[:email],
            params[:password]
          )

          if user
            assign_session_user(user['id'])
            render json: success_response(user), status: :ok
          else
            render json: { error: 'Invalid email or password' }, status: :unauthorized
          end
        end

        def destroy
          clear_session_user
          head :no_content
        end

        private

        def success_response(user)
          {
            user: {
              id: user['id'],
              email: user['email'],
              name: user['name']
            }
          }
        end
      end
    end
  end
end
