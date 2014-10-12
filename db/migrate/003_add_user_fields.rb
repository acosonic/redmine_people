class AddUserFields < ActiveRecord::Migration
  def self.up
    add_column :users, :company_id, :integer, :default => 0
    add_column :users, :category, :smallint, :default => 0
  end

  def self.down
    remove_column :users, :company_id
    remove_column :users, :category
  end

end
