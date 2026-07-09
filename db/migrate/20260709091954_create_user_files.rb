class CreateUserFiles < ActiveRecord::Migration[8.1]
  def change
    create_table :user_files do |t|
      t.string :name
      t.string :file_type
      t.bigint :file_size
      t.string :status
      t.string :s3_key
      t.references :user, null: false, foreign_key: true
      t.datetime :processed_at

      t.timestamps
    end
  end
end
