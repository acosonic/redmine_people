module RedminePeople
  module Hooks
    class ViewsLayoutsHook < Redmine::Hook::ViewListener
      def view_layouts_base_html_head(context={})
        return stylesheet_link_tag(:people, :plugin => 'redmine_people')
      end
      
      def view_users_form(context={})
        context[:controller].send(:render, {:partial => 'hooks/view_user_form'})
      end
      
    end
  end
end