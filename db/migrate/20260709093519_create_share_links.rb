class CreateShareLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :share_links do |t|
      t.references :user_file, null: false, foreign_key: true
      t.string :token, null: false
      t.datetime :expires_at
      t.integer :access_count, default: 0, null: false
      t.integer :max_accesses
      t.string :passcode_digest

      t.timestamps
    end
    add_index :share_links, :token, unique: true
  end
end
