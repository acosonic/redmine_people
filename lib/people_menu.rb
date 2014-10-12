require_dependency 'redmine/menu_manager'

# redmine only differs between project_menu and application_menu! but we want to display the
# people submenu only if the plugin specific controllers are called
module Redmine::MenuManager::MenuHelper
  def display_main_menu?(project)
    Redmine::MenuManager.items(menu_name(project)).children.present?
  end

  def render_main_menu(project)
    render_menu(menu_name(project), project)
  end

  private

  def menu_name(project)
    if project && !project.new_record?
      :project_menu
    else
      if %w(people resource).include? params[:controller]
        :people_menu
      else
        :application_menu
      end
    end
  end
end
