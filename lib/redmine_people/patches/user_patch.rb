require_dependency 'project'
require_dependency 'principal'
require_dependency 'user'

module RedminePeople
  module Patches

    module UserPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable
          scope :staff, lambda { where(:category => Person::STAFF) }
          has_one :avatar, :class_name => "Attachment", :as  => :container, :conditions => "#{Attachment.table_name}.description = 'avatar'", :dependent => :destroy
          acts_as_attachable_global
        end
      end

      module InstanceMethods
        #check if user is company staff or not
        def is_staff
          self.category==Person::STAFF ? true:false
        end

        def project
          @project ||= Project.new
        end
        
        #permission to access People module
        def allowed_people_to?(permission, person = nil)
          return true if admin?
          return true if person && person.is_a?(User) && person.id == self.id && [:view_people, :edit_people].include?(permission)
          return false unless RedminePeople.available_permissions.include?(permission)
          return true if [:view_people, :view_resource].include?(permission) && self.is_staff && self.is_a?(User) && 
                         !self.anonymous? && Setting.plugin_redmine_people["visibility"].to_s == "1"

          (self.groups + [self]).map{|principal| PeopleAcl.allowed_to?(principal, permission) }.inject{|memo,allowed| memo || allowed }
        end

      end
    end

  end
end

unless User.included_modules.include?(RedminePeople::Patches::UserPatch)
  User.send(:include, RedminePeople::Patches::UserPatch)
end

User.safe_attributes 'category'


