# Clear existing data to avoid duplicates during re-seeding
puts "Cleaning database..."
ShareLink.destroy_all
ProcessingJob.destroy_all
UserFile.destroy_all
User.destroy_all

puts "Creating test user..."
user = User.create!(
  email: 'test@example.com',
  password: 'password',
  password_confirmation: 'password'
)
puts "User test@example.com created with password 'password'"

puts "Creating seed files and processing jobs..."

# 1. Processed Image
file1 = UserFile.create!(
  user: user,
  name: 'sunset_beach.jpg',
  file_type: 'image/jpeg',
  file_size: 2_453_910, # 2.3 MB
  status: 'processed',
  processed_at: 10.minutes.ago
)
ProcessingJob.create!(
  user_file: file1,
  status: 'completed',
  result: { 
    width: 1920, 
    height: 1080, 
    format: 'JPEG', 
    tags: ['image', 'photo', 'sunset', 'beach', 'scenery'],
    summary: 'Simulated Amazon Rekognition run: Identified a JPEG image with dimensions 1920x1080. Key tags include sunset, beach, and ocean scenery. No unsafe content detected.',
    simulated: true 
  }
)

# 2. Processed PDF
file2 = UserFile.create!(
  user: user,
  name: 'AWS_S3_DeepDive.pdf',
  file_type: 'application/pdf',
  file_size: 15_821_490, # 15.1 MB
  status: 'processed',
  processed_at: 5.minutes.ago
)
ProcessingJob.create!(
  user_file: file2,
  status: 'completed',
  result: { 
    pages: 42, 
    tags: ['document', 'pdf', 'aws', 's3', 'storage', 'cloud'],
    summary: 'Simulated Amazon Bedrock run: Analyzed document text. Identified a 42-page technical guide outlining Amazon S3 storage classes, bucket security settings, and lifecycles.',
    simulated: true 
  }
)

# 3. Processed Document
file3 = UserFile.create!(
  user: user,
  name: 'notes.txt',
  file_type: 'text/plain',
  file_size: 12_405, # 12 KB
  status: 'processed',
  processed_at: 2.minutes.ago
)
ProcessingJob.create!(
  user_file: file3,
  status: 'completed',
  result: { 
    info: 'Processed text/generic file', 
    tags: ['text', 'notes', 'personal', 'ideas'],
    summary: 'Simulated Bedrock content parsing: Identified raw text document containing personal study notes, brainstorming ideas, and project checklists.',
    simulated: true 
  }
)

# 4. Failed processing
file4 = UserFile.create!(
  user: user,
  name: 'damaged_archive.zip',
  file_type: 'application/zip',
  file_size: 45_120_800, # 43 MB
  status: 'failed',
  processed_at: 1.minute.ago
)
ProcessingJob.create!(
  user_file: file4,
  status: 'failed',
  error_message: 'Invalid ZIP format: End-of-central-directory signature not found'
)

# 5. Uploading in progress
UserFile.create!(
  user: user,
  name: 'large_recording.mov',
  file_type: 'video/quicktime',
  file_size: 214_500_000, # 204 MB
  status: 'uploading'
)

# 6. Processing in progress
file6 = UserFile.create!(
  user: user,
  name: 'analytics_report.xlsx',
  file_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  file_size: 1_230_400, # 1.1 MB
  status: 'processing'
)
ProcessingJob.create!(
  user_file: file6,
  status: 'queued'
)

puts "Database seeded successfully! Created 1 user, #{UserFile.count} files, and #{ProcessingJob.count} processing jobs."
