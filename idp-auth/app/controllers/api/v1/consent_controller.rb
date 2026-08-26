module Api
  module V1
    class ConsentController < ApplicationController
      def create
        return head :unauthorized unless authenticated?

        client_id = params[:client_id]
        scope = params[:scope]
        approved = ActiveModel::Type::Boolean.new.cast(params[:approved])

        if approved
          Consent.record!(
            user_id: current_session_user_id,
            client_id: client_id,
            scope: scope
          )
        end

        render json: { approved: approved }
      end
    end
  end
end
