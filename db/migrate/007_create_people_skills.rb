class CreatePeopleSkills < ActiveRecord::Migration
  def change
    create_table :people_skills do |t|
      t.integer   :user_id, :default => 0, :null => false
      t.integer   :skill_id, :default => 0, :null => false
      t.integer   :skill_attribute_id
    end

  end
end
