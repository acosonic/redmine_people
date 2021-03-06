require 'redmine_people'
require 'people_menu'
require 'date_function'

Redmine::Plugin.register :redmine_people do
  name 'Redmine People plugin'
  author 'RedmineCRM'
  description 'This is a plugin for managing Redmine users'
  version '0.1.8'
  url 'http://redminecrm.com/projects/people'
  author_url 'mailto:support@redminecrm.com'

  requires_redmine :version_or_higher => '2.1.0'

  settings :default => {
    :users_acl => {},
    :visibility => ''
  }

  menu :top_menu, :people, {:controller => 'people', :action => 'index', :project_id => nil}, :caption => :label_people, :if => Proc.new {
    User.current.allowed_people_to?(:view_people)
  }
  menu :admin_menu, :people, {:controller => 'people_settings', :action => 'index'}, :caption => :label_people
  
  Redmine::MenuManager.map :people_menu do |menu|
    menu.push :people, {:controller => 'people', :action => 'index'}, :caption => :label_people,
              :if => Proc.new {User.current.allowed_people_to?(:view_people)}
	  menu.push :resource, {:controller => 'resource', :action => 'index'}, :caption => :label_hr_resource,
              :if => Proc.new {User.current.allowed_people_to?(:view_resource)}
  end
  
end
