module Api
  module V1
    class ChatController < ApplicationController
      # POST /api/v1/chat
      def query
        prompt = params[:prompt]&.strip&.downcase
        file_id = params[:user_file_id]

        if prompt.blank?
          return render json: { error: 'Prompt is required' }, status: :bad_request
        end

        if file_id.present?
          # Chatting with a single specific file
          file = current_user.user_files.find_by(id: file_id)
          if file.nil?
            return render json: { error: 'File not found' }, status: :not_found
          end
          response = handle_single_file_chat(file, prompt)
        else
          # Global chat with all vault files
          files = current_user.user_files.includes(:processing_job).all
          response = handle_global_vault_chat(files, prompt)
        end

        render json: { response: response }
      end

      private

      def handle_single_file_chat(file, prompt)
        job = file.processing_job
        result = job&.result || {}
        tags = result['tags'] || []
        summary = result['summary'] || job&.error_message || 'No summary details available.'

        if prompt.include?('summary') || prompt.include?('summarize') || prompt.include?('about') || prompt.include?('what is')
          "**AI Summary:** #{summary}"
        elsif prompt.include?('tag') || prompt.include?('label')
          if tags.any?
            "The file **#{file.name}** has the following auto-detected tags: #{tags.map { |t| "`##{t}`" }.join(', ')}."
          else
            "No tags have been detected for **#{file.name}**."
          end
        elsif prompt.include?('size') || prompt.include?('bytes') || prompt.include?('large')
          "The file size of **#{file.name}** is **#{ActiveSupport::NumberHelper.number_to_human_size(file.file_size)}** (#{file.file_size} bytes)."
        elsif prompt.include?('status') || prompt.include?('job')
          "The current processing status is **#{file.status.upcase}**. " +
            (job ? "The job is recorded as **#{job.status}**." : "No active job detail.")
        else
          "I am analyzing **#{file.name}** (#{file.file_type}). Here are some questions you can ask me:\n" \
          "1. *\"Summarize this file\"*\n" \
          "2. *\"What tags are detected?\"*\n" \
          "3. *\"How large is this file?\"*"
        end
      end

      def handle_global_vault_chat(files, prompt)
        if files.empty?
          return "Your CloudVault is currently empty. Please upload some files first so I can analyze them for you!"
        end

        # Helper categorizations
        failed_files = files.select { |f| f.status == 'failed' }
        processing_files = files.select { |f| f.status == 'processing' }
        processed_files = files.select { |f| f.status == 'processed' }

        if prompt.include?('failed') || prompt.include?('error') || prompt.include?('broken')
          if failed_files.any?
            res = "I found **#{failed_files.count} failed file(s)** in your vault:\n"
            failed_files.each do |f|
              err = f.processing_job&.error_message || 'Unknown processing error.'
              res += "* **#{f.name}** — Error details: *#{err}*\n"
            end
            res += "\nYou can click the **Retry** button in the files list to re-run the processor."
          else
            "Great news! There are **no failed files** in your vault. All uploads processed successfully."
          end

        elsif prompt.include?('pdf') || prompt.include?('document') || prompt.include?('doc')
          pdfs = files.select { |f| f.file_type == 'application/pdf' }
          if pdfs.any?
            res = "You have **#{pdfs.count} PDF document(s)**:\n"
            pdfs.each do |f|
              summary = f.processing_job&.result&.[]('summary') || 'No summary available.'
              res += "* **#{f.name}** — *#{summary}*\n"
            end
            res
          else
            "You don't have any PDF documents uploaded yet."
          end

        elsif prompt.include?('image') || prompt.include?('photo') || prompt.include?('pic')
          images = files.select { |f| f.file_type.start_with?('image/') }
          if images.any?
            res = "You have **#{images.count} image file(s)**:\n"
            images.each do |f|
              res += "* **#{f.name}** — Dimensions: *#{f.processing_job&.result&.[]('width')}x#{f.processing_job&.result&.[]('height')}*\n"
            end
            res
          else
            "No images found in your vault."
          end

        elsif prompt.include?('summarize') || prompt.include?('summary')
          # Check if they want to summarize a specific file
          matched_file = files.find { |f| prompt.include?(f.name.split('.').first) }
          if matched_file
            summary = matched_file.processing_job&.result&.[]('summary') || 'No summary details found.'
            "**Summary of #{matched_file.name}:** #{summary}"
          else
            "You have **#{files.count} total files** in your vault:\n" \
            "- **#{processed_files.count}** Processed successfully\n" \
            "- **#{processing_files.count}** Processing\n" \
            "- **#{failed_files.count}** Failed\n\n" \
            "Try asking me to summarize a specific file, e.g. *\"Summarize sunset_beach\"*!"
          end

        # Check tag matches (e.g. sunset, beach, aws, finance, notes)
        elsif prompt.include?('sunset') || prompt.include?('beach')
          beach_files = files.select { |f| f.name.include?('beach') || f.processing_job&.result&.[]('tags')&.include?('beach') }
          if beach_files.any?
            "I found beach-related files:\n" + beach_files.map { |f| "* **#{f.name}**: *#{f.processing_job&.result&.[]('summary')}*" }.join("\n")
          else
            "No beach or sunset files found in your vault."
          end

        elsif prompt.include?('aws') || prompt.include?('cloud') || prompt.include?('s3')
          aws_files = files.select { |f| f.name.downcase.include?('aws') || f.processing_job&.result&.[]('tags')&.include?('aws') }
          if aws_files.any?
            "Here are the cloud architecture documents in your vault:\n" + aws_files.map { |f| "* **#{f.name}**: *#{f.processing_job&.result&.[]('summary')}*" }.join("\n")
          else
            "No AWS or Cloud documentation found in your vault."
          end

        elsif prompt.include?('how many') || prompt.include?('count')
          total_size = files.sum(&:file_size)
          "Your vault currently holds **#{files.count} file(s)**, consuming a total of **#{ActiveSupport::NumberHelper.number_to_human_size(total_size)}** of virtual storage space."

        else
          "Hi! I am your **CloudVault AI Assistant**. 🧠 I can help you search and analyze the contents of your vault.\n\n" \
          "Here are some examples of what you can ask me:\n" \
          "* *\"Summarize my files\"*\n" \
          "* *\"Which files failed?\"*\n" \
          "* *\"Show my image files\"*\n" \
          "* *\"What AWS documents do I have?\"*"
        end
      end
    end
  end
end
