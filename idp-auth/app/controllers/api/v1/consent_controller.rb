module Api
  module V1
    class ConsentController < ApplicationController
      def create
        return head :unauthorized unless authenticated?

        approved = ActiveModel::Type::Boolean.new.cast(params[:approved])
        if approved
          return render json: { error: 'invalid_request' }, status: :bad_request unless required_params_present?

          Consent.record!(user_id: current_session_user_id, client_id: params[:client_id], scope: params[:scope])
        end

        render json: { approved: approved }
      end

      private

      def required_params_present?
        params[:client_id].present? && params[:scope].present?
      end
    end
  end
end
