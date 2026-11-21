module Api
  module V1
    module Auth
      class SessionController < ApplicationController
        include CsrfProtectedApi

        def create
          user = ::Auth::SessionService.authenticate(
            params[:email],
            params[:password]
          )
          return render_unauthorized unless user

          renew_session
          assign_session_user(user['id'])
          render json: success_response(user), status: :ok
        end

        def destroy
          clear_session_user
          head :no_content
        end

        private

        # セッション固定攻撃への対策でセッションを作り直すが、/authorize が中断したリクエストは引き継ぐ
        def renew_session
          pending_authorization = session[:authorize_params]
          reset_session
          session[:authorize_params] = pending_authorization if pending_authorization
        end

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
