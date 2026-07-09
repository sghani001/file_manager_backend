class ShareLink < ApplicationRecord
  belongs_to :user_file

  before_validation :generate_token, on: :create

  validates :token, presence: true, uniqueness: true

  # Setter for passcode that hashes it using BCrypt
  def passcode=(raw_password)
    if raw_password.present?
      self.passcode_digest = BCrypt::Password.create(raw_password)
    else
      self.passcode_digest = nil
    end
  end

  # Verifies the passcode
  def authenticate_passcode(raw_password)
    return true if passcode_digest.nil? # No passcode required
    return false if raw_password.blank?
    
    BCrypt::Password.new(passcode_digest) == raw_password
  rescue BCrypt::Errors::InvalidHash
    false
  end

  # Checks if the link has expired (by time or access limit)
  def expired?
    # Time-based expiry
    return true if expires_at.present? && Time.current > expires_at
    
    # Download limit-based expiry
    return true if max_accesses.present? && access_count >= max_accesses
    
    false
  end

  private

  def generate_token
    loop do
      self.token = SecureRandom.urlsafe_base64(16)
      break unless ShareLink.exists?(token: token)
    end
  end
end
