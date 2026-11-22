module Api
  module V1
    class ConsentController < ApplicationController
      include CsrfProtectedApi

      def create
        return head :unauthorized unless authenticated?

        approved = ActiveModel::Type::Boolean.new.cast(params[:approved])
        if approved
          return render json: { error: 'invalid_request' }, status: :bad_request unless required_params_present?

          Consent.record!(user_id: current_session_user_id, client_id: params[:client_id], scope: params[:scope])
        end

        render json: { approved: approved, redirect_to: next_location(approved) }
      end

      private

      def required_params_present?
        params[:client_id].present? && params[:scope].present?
      end

      # /authorize が同意のために中断していれば、同意後に frontend が遷移する先を返す。
      # 承認なら認可を再開し、拒否なら RP に access_denied を返す（OAuth 2.0 RFC 6749 §4.1.2.1）
      def next_location(approved)
        stored = session[:authorize_params]
        return nil if stored.blank?
        return "#{Oidc::Discovery::ISSUER}/authorize/continue" if approved

        session.delete(:authorize_params)
        ::Auth::RedirectUri.build(stored['redirect_uri'], error: 'access_denied', state: stored['state'])
      end
    end
  end
end
