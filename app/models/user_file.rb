class UserFile < ApplicationRecord
  belongs_to :user
  has_one :processing_job, dependent: :destroy
  has_many :share_links, dependent: :destroy

  before_create :generate_s3_key

  def presigned_upload_url
    bucket_name = ENV['AWS_BUCKET_NAME']

    if bucket_name.present?
      require 'aws-sdk-s3'
      s3 = Aws::S3::Resource.new(region: ENV['AWS_REGION'])
      bucket = s3.bucket(bucket_name)
      bucket.object(s3_key).presigned_url(:put, expires_in: 3600)
    else
      "/api/v1/local_s3_uploads?s3_key=#{CGI.escape(s3_key)}"
    end
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
