class CreateProcessingJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :processing_jobs do |t|
      t.references :user_file, null: false, foreign_key: true
      t.string :status
      t.json :result
      t.text :error_message

      t.timestamps
    end
  end
end
