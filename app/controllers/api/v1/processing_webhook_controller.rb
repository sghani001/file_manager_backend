module Api
  module V1
    class ProcessingWebhookController < ApplicationController
      skip_before_action :authorized

      def handle
        secret = request.headers['X-Lambda-Webhook-Secret']
        expected = ENV['LAMBDA_WEBHOOK_SECRET']

        unless secret.present? && expected.present? && ActiveSupport::SecurityUtils.secure_compare(secret, expected)
          return render json: { error: 'Unauthorized' }, status: :unauthorized
        end

        s3_key = params[:s3_key]
        result = params[:result]

        unless s3_key.present? && result.present?
          return render json: { error: 'Missing s3_key or result' }, status: :bad_request
        end

        file = UserFile.find_by(s3_key: s3_key)
        unless file
          return render json: { error: 'File not found' }, status: :not_found
        end

        file.processing_job.update!(
          status: 'completed',
          result: result
        )
        file.update!(
          status: 'processed',
          processed_at: Time.current
        )

        render json: { status: 'processed' }
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end
    end
  end
end
