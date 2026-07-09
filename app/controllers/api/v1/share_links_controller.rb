module Api
  module V1
    class ShareLinksController < ApplicationController
      # Skip authentication for downloading public share links
      skip_before_action :authorized, only: [:show, :validate_passcode]

      # POST /api/v1/share_links
      def create
        file = current_user.user_files.find(params[:user_file_id])
        
        # Calculate expiry if minutes are provided
        expires_at = nil
        if params[:expires_in_minutes].present? && params[:expires_in_minutes].to_i > 0
          expires_at = Time.current + params[:expires_in_minutes].to_i.minutes
        end

        link = file.share_links.new(
          expires_at: expires_at,
          max_accesses: params[:max_accesses].presence,
          passcode: params[:passcode].presence
        )

        if link.save
          render json: {
            share_url: "http://localhost:5173/share/#{link.token}", # React route
            token: link.token,
            expires_at: link.expires_at,
            max_accesses: link.max_accesses,
            requires_passcode: link.passcode_digest.present?
          }, status: :created
        else
          render json: { errors: link.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/share_links/:token (Validates and triggers download)
      def show
        link = ShareLink.find_by(token: params[:token])
        
        if link.nil? || link.expired?
          link&.destroy # Clean up expired link
          return render json: { error: 'This link has expired or self-destructed' }, status: :not_found
        end

        # Check passcode protection
        if link.passcode_digest.present?
          passcode = request.headers['X-Share-Passcode'].presence || params[:passcode].presence
          if passcode.blank?
            return render json: { requires_passcode: true }, status: :unauthorized
          elsif !link.authenticate_passcode(passcode)
            return render json: { error: 'Incorrect passcode' }, status: :forbidden
          end
        end

        # Increment access count
        link.increment!(:access_count)

        # Download logic
        file = link.user_file
        file_path = Rails.root.join('public', 'uploads', file.s3_key)

        # Check if max accesses has been reached, destroy if expired now (Self-destruct)
        if link.expired?
          link.destroy
        end

        if ::File.exist?(file_path)
          send_file file_path, filename: file.name, type: file.file_type, disposition: 'attachment'
        else
          # Fallback send data for seeded files that do not exist physically on disk
          send_data "CloudVault Download Simulator:\nFile Name: #{file.name}\nSize: #{file.file_size} bytes\nType: #{file.file_type}\nStatus: Processed", 
                    filename: file.name, 
                    type: file.file_type, 
                    disposition: 'attachment'
        end
      end

      # POST /api/v1/share_links/:token/validate
      # Helper endpoint for UI to verify passcode before download trigger
      def validate_passcode
        link = ShareLink.find_by(token: params[:token])

        if link.nil? || link.expired?
          link&.destroy
          return render json: { error: 'Link expired or invalid' }, status: :not_found
        end

        if link.passcode_digest.nil?
          return render json: { valid: true, requires_passcode: false }
        end

        passcode = params[:passcode]
        if passcode.present? && link.authenticate_passcode(passcode)
          render json: { valid: true, requires_passcode: true }
        else
          render json: { error: 'Incorrect passcode' }, status: :forbidden
        end
      end
    end
  end
end
