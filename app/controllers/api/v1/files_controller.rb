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
        
        # Trigger background processing simulator
        trigger_processing_simulator(file)
        
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

      def trigger_processing_simulator(file)
        # Simulate AWS EventBridge -> Lambda processing in a background thread
        Thread.new do
          # Sleep for 2 seconds to simulate asynchronous AWS Lambda start & execution
          sleep 2

          begin
            result = {}
            # Locate the uploaded file on local disk
            local_path = Rails.root.join('public', 'uploads', file.s3_key)

            if file.file_type.start_with?('image/')
              # Simple image processing simulation
              width = rand(800..1920)
              height = rand(600..1080)
              format = file.file_type.split('/').last.upcase
              result = {
                width: width,
                height: height,
                format: format,
                tags: ['image', 'photo', 'visual', format.downcase],
                summary: "Simulated Amazon Rekognition run: Identified a #{format} image with dimensions #{width}x#{height}. No explicit content detected.",
                simulated: true
              }
            elsif file.file_type == 'application/pdf'
              # Simple PDF processing simulation
              pages = rand(1..50)
              result = {
                pages: pages,
                tags: ['document', 'pdf', 'archive', 'reference'],
                summary: "Simulated Amazon Bedrock run: Analyzed document text. Identified a #{pages}-page PDF outlining reference documentation and guides.",
                simulated: true
              }
            else
              result = {
                info: "Processed text/generic file",
                tags: ['data', 'text', 'generic'],
                summary: "Simulated Bedrock content parsing: Read general text structure. Extracted basic data fields and labels.",
                simulated: true
              }
            end

            # Update database records
            file.processing_job.update!(
              status: 'completed',
              result: result
            )
            file.update!(
              status: 'processed',
              processed_at: Time.current
            )
          rescue => e
            file.processing_job.update!(
              status: 'failed',
              error_message: e.message
            )
            file.update!(status: 'failed')
          end
        end
      end
    end
  end
end
