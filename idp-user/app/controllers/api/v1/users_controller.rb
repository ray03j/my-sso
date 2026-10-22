module Api
  module V1
    class UsersController < ApplicationController
      before_action :require_internal_api_key, only: %i[create show]

      def show
        user = User.find(params[:id])
        render json: { id: user.id, email: user.email, name: user.name }
      end

      def create
        user = User.new(user_params)
        if user.save
          render json: { id: user.id, email: user.email, name: user.name }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_content
        end
      end

      private

      def user_params
        params.require(:user).permit(:email, :password, :name)
      end
    end
  end
end
