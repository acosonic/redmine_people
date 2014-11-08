class SkillCategory < ActiveRecord::Base
  include Redmine::SafeAttributes
  unloadable
  
  has_many :skill, :uniq => true, :dependent => :nullify
  
  safe_attributes 'name'
  
  def to_s
    name
  end
  
end
