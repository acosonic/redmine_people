require 'resource_gantt'
class ResourceController < ApplicationController
  unloadable
  
  layout 'people'
  
  before_filter :authorize_people
  
  include PeopleHelper
  include ResourceHelper
  
  helper :departments
  helper :gantt
  helper :projects
  helper :sort
  helper :resource
  include SortHelper
  
  
  def index
    @gantt = Redmine::People::Gantt.new(params)
    @departments = Department.order(:name)
    @groups = Group.order(:lastname)
    respond_to do |format|
      format.html { render :action => "index", :layout => !request.xhr? }
    end
  end
  
  def show
    
  end
  
private
  def authorize_people
    allowed = case params[:action].to_s
      when "index", "show"
        User.current.allowed_people_to?(:view_resource, @person)
      else
        false
      end

    if allowed
      true
    else
      deny_access
    end
  end
  
end
