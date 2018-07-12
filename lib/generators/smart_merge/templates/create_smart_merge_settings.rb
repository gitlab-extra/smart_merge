class CreateSmartMergeSettings < ActiveRecord::Migration
  def change
    create_table :smart_merge_settings do |t|
      t.references :project
      t.string :target_branch
      t.text :base_branch
      t.text :source_branches
      t.text :conflicts
      t.integer :status, default: 2
      t.boolean :auto_merge, default: true
      t.integer :creator

      t.timestamps null: false
    end
    add_index :light_merges, :project_id
    add_index :light_merges, :target_branch
    add_index :light_merges, :status
  end
end
