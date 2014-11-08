class CreateSkillAttributes < ActiveRecord::Migration
  def change
    create_table :skill_attributes do |t|
      t.string    :name, :limit => 100
    end

  end
end
