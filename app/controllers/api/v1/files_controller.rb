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
        local_path = Rails.root.join('public', 'uploads', file.s3_key)
        if ::File.exist?(local_path)
          send_file local_path, type: file.file_type, filename: file.name
        else
          render json: { error: 'File not found on disk' }, status: :not_found
        end
      end

      private
    end
  end
end
