class UserFile < ApplicationRecord
  belongs_to :user
  has_one :processing_job, dependent: :destroy
  has_many :share_links, dependent: :destroy

  before_create :generate_s3_key

  def presigned_upload_url
    # Local upload via nginx proxy — files stored on EC2 disk under public/uploads/
    "/api/v1/local_s3_uploads?s3_key=#{CGI.escape(s3_key)}"
  end

  def mark_processing
    update(status: 'processing')
    if processing_job
      processing_job.update!(status: 'queued', result: nil, error_message: nil)
    else
      create_processing_job!(status: 'queued')
    end
  end

  private

  def generate_s3_key
    safe_name = name.presence || 'file'
    self.s3_key = "files/#{SecureRandom.uuid}/#{safe_name}"
  end
end
