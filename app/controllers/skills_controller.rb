class SkillsController < ApplicationController
  unloadable

  before_filter :require_admin
  before_filter :find_category, :only => [:new_category, :edit_category, :update_category, :remove_category]

  def index
  end

  
  def new_category
    
  end
  
  def edit_category
    
  end

  def update_category
    @skill_category.safe_attributes = params[:skill_category]
    if @skill_category.save 
      respond_to do |format| 
        format.html { redirect_to :controller =>"people_settings", :action => "index", :tab => "skill_categories" } 
      end
    else
      respond_to do |format|
        format.html { render :action => 'edit_category' }
      end      
    end    
  end
  
  def remove_category
  end

private
  def find_category
    if params[:id].blank? 
      @skill_category = SkillCategory.new
    else
      @skill_category = SkillCategory.find(params[:id])
    end
  end
  
end
