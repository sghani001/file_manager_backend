module Api
  module V1
    class AuthenticationController < ApplicationController
      skip_before_action :authorized, only: [:signup, :login]

      def signup
        user = User.new(user_params)
        if user.save
          token = encode_token({ user_id: user.id })
          render json: { user: { id: user.id, email: user.email }, token: token }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def login
        user = User.find_by(email: params[:email]&.downcase)
        if user && user.authenticate(params[:password])
          token = encode_token({ user_id: user.id })
          render json: { user: { id: user.id, email: user.email }, token: token }, status: :ok
        else
          render json: { error: 'Invalid email or password' }, status: :unauthorized
        end
      end

      def profile
        render json: { user: { id: current_user.id, email: current_user.email } }, status: :ok
      end

      private

      def user_params
        params.permit(:email, :password)
      end
    end
  end
end
