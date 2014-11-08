class Skill < ActiveRecord::Base
  include Redmine::SafeAttributes
  unloadable
  
  belongs_to :skill_category
  
  safe_attributes 'name'
  
  def to_s
    name
  end
  
  # skill category
  PEOPLE = 0
  PROJECT = 1

  
end
