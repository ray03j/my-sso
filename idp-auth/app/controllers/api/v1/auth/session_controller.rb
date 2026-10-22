module Api
  module V1
    module Auth
      class SessionController < ApplicationController
        def create
          user = ::Auth::SessionService.authenticate(
            params[:email],
            params[:password]
          )
          return render_unauthorized unless user

          reset_session
          assign_session_user(user['id'])
          render json: success_response(user), status: :ok
        end

        def destroy
          clear_session_user
          head :no_content
        end

        private

        def render_unauthorized
          render json: { error: 'Invalid email or password' }, status: :unauthorized
        end

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
