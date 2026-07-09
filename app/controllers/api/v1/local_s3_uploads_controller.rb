module Api
  module V1
    class LocalS3UploadsController < ApplicationController
      before_action :authorized

      def create
        s3_key = params[:s3_key]
        if s3_key.blank?
          return render json: { error: 's3_key parameter is required' }, status: :bad_request
        end

        # Verify the file belongs to the current user
        file = current_user.user_files.find_by(s3_key: s3_key)
        if file.nil?
          return render json: { error: 'File record not found' }, status: :not_found
        end

        # Clean the s3_key and ensure it doesn't try to directory traverse
        clean_key = s3_key.gsub('..', '')
        
        # Build path in public/uploads/files/<uuid>/filename
        upload_path = Rails.root.join('public', 'uploads', clean_key)
        
        # Create directories if they do not exist
        FileUtils.mkdir_p(::File.dirname(upload_path))

        # Read binary body and write to file
        binary_data = request.body.read
        
        ::File.open(upload_path, 'wb') do |f|
          f.write(binary_data)
        end

        head :ok
      rescue => e
        render json: { error: "Failed to upload locally: #{e.message}" }, status: :internal_server_error
      end
    end
  end
end
