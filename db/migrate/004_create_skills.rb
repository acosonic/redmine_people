class CreateSkills < ActiveRecord::Migration
  def change
    create_table :skills do |t|
      t.integer   :type, :limit => 1, :default => 0
      t.integer   :category_id, :default => 0, :null => false
      t.string    :name, :limit => 100
      t.string    :attributes, :limit => 50
    end

  end
end
