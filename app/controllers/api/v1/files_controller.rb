module Api
  module V1
    class FilesController < ApplicationController
      MAX_FILE_SIZE = 50.megabytes

      def create_presigned_url
        if params[:file_size].to_i > MAX_FILE_SIZE
          return render json: { error: "File exceeds maximum size of #{MAX_FILE_SIZE / 1.megabyte}MB" }, status: :unprocessable_entity
        end

        file = UserFile.create!(
          name: params[:filename],
          file_type: params[:file_type],
          file_size: params[:file_size],
          user_id: current_user.id,
          status: 'uploading'
        )
        render json: {
          file_id: file.id,
          presigned_url: file.presigned_upload_url,
          s3_key: file.s3_key
        }
      end

      def mark_uploaded
        file = UserFile.find(params[:id])
        file.mark_processing
        render json: { status: 'processing' }
      end

      def index
        files = UserFile.where(user_id: current_user.id).includes(:processing_job).order(created_at: :desc)
        render json: files, include: :processing_job
      end

      def download
        file = current_user.user_files.find(params[:id])
        signer = Aws::S3::Presigner.new
        url = signer.presigned_url(:get_object,
          bucket: ENV['AWS_BUCKET_NAME'],
          key: file.s3_key,
          expires_in: 3600
        )
        redirect_to url, allow_other_host: true
      end

      def reprocess
        file = current_user.user_files.find(params[:id])
        file.update!(status: 'processing')
        file.create_processing_job!(status: 'queued') unless file.processing_job
        file.processing_job.update!(status: 'queued', result: nil, error_message: nil)

        # Invoke Lambda with a synthetic S3 event to reprocess the file
        Thread.new do
          begin
            require 'aws-sdk-lambda'
            lambda = Aws::Lambda::Client.new(region: ENV['AWS_REGION'] || 'us-east-1')
            lambda.invoke(
              function_name: 'cloudvault-file-processor',
              invocation_type: 'Event',
              payload: JSON.generate({
                version: '0',
                id: SecureRandom.uuid,
                'detail-type': 'Object Created',
                source: 'aws.s3',
                account: '',
                time: Time.current.iso8601,
                region: ENV['AWS_REGION'] || 'us-east-1',
                resources: ["arn:aws:s3:::#{ENV['AWS_BUCKET_NAME']}"],
                detail: {
                  version: '0',
                  bucket: { name: ENV['AWS_BUCKET_NAME'] },
                  object: {
                    key: file.s3_key,
                    size: file.file_size,
                    etag: '',
                    'version-id': '',
                    sequencer: ''
                  },
                  'request-id': '',
                  requester: '',
                  'source-ip-address': '',
                  reason: 'PutObject'
                }
              })
            )
          rescue => e
            Rails.logger.error("Lambda invocation failed: #{e.message}")
          end
        end

        render json: { status: 'processing' }
      end

      private
    end
  end
end
