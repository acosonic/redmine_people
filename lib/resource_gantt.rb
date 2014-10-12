# Redmine - project management software
# Copyright (C) 2006-2014  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

module Redmine
  module People
    # Simple class to handle gantt chart data
    class Gantt
      include ERB::Util
      include Redmine::I18n
      include Redmine::Utils::DateCalculation

      # Relation types that are rendered
      DRAW_TYPES = {
        IssueRelation::TYPE_BLOCKS   => { :landscape_margin => 16, :color => '#F34F4F' },
        IssueRelation::TYPE_PRECEDES => { :landscape_margin => 20, :color => '#628FEA' }
      }.freeze

      # :nodoc:
      # Some utility methods for the PDF export
      class PDF
        MaxCharactorsForSubject = 45
        TotalWidth = 280
        LeftPaneWidth = 100

        def self.right_pane_width
          TotalWidth - LeftPaneWidth
        end
      end

      attr_reader :department_id, :group_id,:person_id, :year_from, :month_from, :date_from, :date_to, :zoom, 
                  :months, :truncated, :max_rows, :work_on_weekends, :disp
      attr_accessor :person
      attr_accessor :department
      attr_accessor :group
      attr_accessor :view

      def initialize(options={})
        options = options.dup
        if options[:year] && options[:year].to_i >0
          @year_from = options[:year].to_i
          if options[:month] && options[:month].to_i >=1 && options[:month].to_i <= 12
            @month_from = options[:month].to_i
          else
            @month_from = 1
          end
        else
          @month_from ||= Date.today.month
          @year_from ||= Date.today.year
        end
        zoom = (options[:zoom] || User.current.pref[:gantt_zoom]).to_i
        @zoom = (zoom > 0 && zoom < 5) ? zoom : 2
        months = (options[:months] || User.current.pref[:gantt_months]).to_i
        @months = (months > 0 && months < 25) ? months : 6
        @work_on_weekends = true #TO-DO
        work_on_weekends = @work_on_weekends
        
        # Save gantt parameters as user preference (zoom and months count)
        if (User.current.logged? && (@zoom != User.current.pref[:hr_gantt_zoom] ||
              @months != User.current.pref[:hr_gantt_months]))
          User.current.pref[:hr_gantt_zoom], User.current.pref[:hr_gantt_months] = @zoom, @months
          User.current.preference.save
        end
        @date_from = Date.civil(@year_from, @month_from, 1)
        @date_to = (@date_from >> @months) - 1
        @subjects = ''
        @lines = ''
        @number_of_rows = nil
        @project_ancestors = []
        @truncated = false
        if options.has_key?(:max_rows)
          @max_rows = options[:max_rows]
        else
          @max_rows = Setting.gantt_items_limit.blank? ? nil : Setting.gantt_items_limit.to_i
        end
        
        if options[:department_id] && options[:department_id].to_i >0
          @department_id ||= options[:department_id]
          @department = Department.find(@department_id) if @department_id.present?
        end
        if options[:group_id] && options[:group_id].to_i >0
          @group_id ||= options[:group_id]
          @group = Group.find(@group_id) if @group_id.present?
        end
        
        if options[:person_id].present?
          @person_id = options[:person_id] if options[:person_id].present?
          @person = Person.find(@person_id) if @person_id.present?
        end
        #display project or not
        @disp = false
        if !@person.present?
          @disp = options[:disp].present? ? true : false
        else
          @disp = true
        end
      end
      
      def common_params
        { :controller => 'resource', :action => 'show', :person_id => @person }
      end

      def params
        disp_value = 'true' if  @disp
        common_params.merge({:zoom => zoom, :year => year_from,:month => month_from,:months => months,
                             :department_id => department_id,:group_id => group_id,:person_id => person_id,:disp => disp_value})
      end

      def params_previous
        disp_value = 'true' if  @disp
        common_params.merge({:year => (date_from << months).year,:month => (date_from << months).month,:zoom => zoom, :months => months,
                             :department_id => department_id,:group_id => group_id,:person_id => person_id,:disp => disp_value})
      end

      def params_next
        disp_value = 'true' if  @disp
        common_params.merge({:year => (date_from >> months).year,:month => (date_from >> months).month,:zoom => zoom, :months => months,
                             :department_id => department_id,:group_id => group_id,:person_id => person_id,:disp => disp_value})
      end

      # Returns the number of rows that will be rendered on the Gantt chart
      def number_of_rows
        return @number_of_rows if @number_of_rows
        rows = people.inject(0) {|total, p| total += number_of_rows_on_person(p)}
        rows > @max_rows ? @max_rows : rows
      end

      # Returns the number of rows that will be used to list a person on
      # the Gantt chart.  
      def number_of_rows_on_person(person)
        return 0 unless people.include?(person)
        count = 1
        count += person.member_projects.size
        count
      end

      # Renders the subjects of the Gantt chart, the left side.
      def subjects(options={})
        render(options.merge(:only => :subjects)) unless @subjects_rendered
        @subjects
      end

      # Renders the lines of the Gantt chart, the right side
      def lines(options={})
        render(options.merge(:only => :lines)) unless @lines_rendered
        @lines
      end
      
      # Return all the persons nodes that will be displayed
      # Only select people from company (has category=STAFF)
      def people
        return @people if @people
        scope = Person.logged.status(Principal::STATUS_ACTIVE)
        scope = scope.staff
        scope = scope.in_department(@department_id) if @department_id.present?
        scope = scope.in_group(@group_id) if @group_id.present?
        scope = scope.where(:id => @person_id) if @person_id.present?
        scope = scope.where(:type => 'User')
        scope
      end

      # render result
      def render(options={})
        options = {:top => 0, :top_increment => 25,
                   :indent_increment => 20, :render => :subject,
                   :format => :html}.merge(options)
        indent = options[:indent] || 4
        @subjects = '' unless options[:only] == :lines
        @lines = '' unless options[:only] == :subjects
        @number_of_rows = 0
        people.each do |person| 
          level = 0
          options[:indent] = indent + level * options[:indent_increment]
          render_person(person, options)
          break if abort?
        end
        @subjects_rendered = true unless options[:only] == :lines
        @lines_rendered = true unless options[:only] == :subjects
        render_end(options)
      end

      def render_person(person, options={})
        subject_for_person(person, options) unless options[:only] == :lines
        line_for_person(person, options) unless options[:only] == :subjects
        options[:top] += options[:top_increment]
        options[:indent] += options[:indent_increment]
        @number_of_rows += 1
        return if abort?
        member_projects = person.member_projects
        self.class.sort_projects!(member_projects)
        if member_projects && @disp
          render_member_projects(member_projects, options)
          return if abort?
        end
        # Remove indent to hit the next sibling
        options[:indent] -= options[:indent_increment]
      end
      
      def render_member_projects(member_projects, options={})
        @issue_ancestors = []
        member_projects.each do |i|
          subject_for_member_project(i, options) unless options[:only] == :lines
          line_for_member_project(i, options) unless options[:only] == :subjects
          options[:top] += options[:top_increment]
          @number_of_rows += 1
          break if abort?
        end
        options[:indent] -= (options[:indent_increment] * @issue_ancestors.size)
      end

      def render_end(options={})
        case options[:format]
        when :pdf
          options[:pdf].Line(15, options[:top], PDF::TotalWidth, options[:top])
        end
      end

      #Draw subject for person
      def subject_for_person(person, options)
        case options[:format]
        when :html
          html_class = ""
          #html_class << 'icon icon-projects '
          
          s = "".html_safe
          s << view.avatar(person,
                             :class => 'gravatar icon-gravatar',
                             :size => 12,
                             :title => person.name).to_s.html_safe
          s << view.link_to(person.name, {:controller => 'resource', :action => 'show', :person_id => person},:class => 'person-name-subject').html_safe
          subject = view.content_tag(:span, s,
                                     :class => html_class).html_safe
          html_subject(options, subject, :css => "person-row")
        when :image
          image_subject(options, person.name)
        when :pdf
          pdf_new_page?(options)
          pdf_subject(options, person.name)
        end
      end
      #Draw line for person
      def line_for_person(person, options)
        # Skip person that don't have a start_date or due date
        if person.is_a?(Person) && person.allocation_from_date && person.allocation_to_date #TO-DO
          options[:zoom] ||= 1
          #options[:g_width] ||= (self.date_to - self.date_from + 1) * options[:zoom]
          options[:g_width] ||= (work_days_in(self.date_to, self.date_from) + 1) * options[:zoom]
          coords = coordinates(person.allocation_from_date, person.allocation_to_date, nil, options[:zoom])
          label = h(person)
          case options[:format]
          when :html
            html_task(options, coords, :css => "person task", :label => label, :markers => true)
          when :image
            image_task(options, coords, :label => label, :markers => true, :height => 3)
          when :pdf
            pdf_task(options, coords, :label => label, :markers => true, :height => 0.8)
          end
        else
          ''
        end
      end
      
      #Draw line for member project
      def subject_for_member_project(mproject, options)
        output = case options[:format]
        when :html
          css_classes = ''
          css_classes << ' icon icon-projects' unless Setting.gravatar_enabled?
          s = "".html_safe
          s << view.link_to_project(mproject.project).html_safe
          s << h(": #{mproject.allocation}%")
          subject = view.content_tag(:span, s, :class => css_classes).html_safe
          html_subject(options, subject, :css => "project-row",
                       :title => mproject.project.name, :id => "project-#{mproject.project.id}") + "\n"
        when :image
          image_subject(options, mproject.project.name)
        when :pdf
          pdf_new_page?(options)
          pdf_subject(options, mproject.project.name)
        end
        
        output
      end

      def line_for_member_project(mproject, options)
        # Skip project that don't have a due_date
        if mproject.to_date
          coords = coordinates(mproject.from_date, mproject.to_date, 0, options[:zoom])
          label = "#{mproject.project.name}:#{mproject.allocation}%"
          case options[:format]
          when :html
            html_task(options, coords,
                      :css => "task ",
                      :label => label,
                      :markers => true)
          when :image
            image_task(options, coords, :label => label)
          when :pdf
            pdf_task(options, coords, :label => label)
        end
        else
          ''
        end
      end

      def work_days_in(date_to, date_from)
        if !@work_on_weekends
          date_to = ensure_workday(date_to)
          date_from = ensure_workday(date_from)
        end
        days_in = date_to - date_from
        if @work_on_weekends
          return days_in
        end
        weekends_in = (days_in / 7).floor
        weekends_in += 1 if date_to.cwday < date_from.cwday
        work_days = days_in - (weekends_in * 2)
        work_days
      end
      
      private

      def coordinates(start_date, end_date, progress, zoom=nil)
        zoom ||= @zoom
        coords = {}
        if start_date && end_date && start_date < self.date_to && end_date > self.date_from
          if start_date > self.date_from
            coords[:start] = start_date - self.date_from
            coords[:bar_start] = start_date - self.date_from
          else
            coords[:bar_start] = 0
          end
          if end_date < self.date_to
            coords[:end] = end_date - self.date_from
            coords[:bar_end] = end_date - self.date_from + 1
          else
            coords[:bar_end] = self.date_to - self.date_from + 1
          end
          if progress
            progress_date = calc_progress_date(start_date, end_date, progress)
            if progress_date > self.date_from && progress_date > start_date
              if progress_date < self.date_to
                coords[:bar_progress_end] = progress_date - self.date_from
              else
                coords[:bar_progress_end] = self.date_to - self.date_from + 1
              end
            end
            if progress_date < Date.today
              late_date = [Date.today, end_date].min
              if late_date > self.date_from && late_date > start_date
                if late_date < self.date_to
                  coords[:bar_late_end] = late_date - self.date_from + 1
                else
                  coords[:bar_late_end] = self.date_to - self.date_from + 1
                end
              end
            end
          end
        end
        # Transforms dates into pixels witdh
        coords.keys.each do |key|
          coords[key] = (coords[key] * zoom).floor
        end
        coords
      end
     # Get the end date for a given start date and duration of workdays.
      # If the number of workdays is 0, the result is equal to the start date.
      # If the number of workdays is 1, the result is equal to the next workday 
      # that follows the start date.
      def date_for_workdays(date_from, workdays)
        if @work_on_weekends
          return date_from + workdays
        end
        days_in = date_from + workdays
        workdays_in_week = @work_on_weekends ? 7 : 5
        weekends = (workdays / workdays_in_week).floor
        date_to = date_from + workdays + (weekends * 2) # candidate result (might end on a weekend)
        weekends += 1 if date_to.cwday >= 6
        weekends += 1 if date_to.cwday < date_from.cwday
        date_to = date_from + workdays + (weekends * 2) # final result
        date_to
      end
      
      # Ensure that the date falls on a workday. If the given date falls on a
      # weekend, it is moved to the following Monday.
      def ensure_workday(date)
        if !@work_on_weekends
          date += 8 - date.cwday if date.cwday >= 6
        end
        date
      end
      
      def calc_progress_date(start_date, end_date, progress)
        start_date + (end_date - start_date + 1) * (progress / 100.0)
      end

      def self.sort_projects!(projects)
        projects.sort! {|a, b| sort_project_logic(a) <=> sort_project_logic(b)}
      end

      def self.sort_project_logic(project)
        julian_date = Date.new()
        ancesters_from_date = []
        ancesters_from_date.unshift([project.from_date || julian_date, project.project.id])
        ancesters_from_date
      end

      def current_limit
        if @max_rows
          @max_rows - @number_of_rows
        else
          nil
        end
      end

      def abort?
        if @max_rows && @number_of_rows >= @max_rows
          @truncated = true
        end
      end

      def html_subject(params, subject, options={})
        style = "position: absolute;top:#{params[:top]}px;left:#{params[:indent]}px;"
        style << "width:#{params[:subject_width] - params[:indent]}px;" if params[:subject_width]
        output = view.content_tag(:div, subject,
                                  :class => options[:css], :style => style,
                                  :title => options[:title],
                                  :id => options[:id])
        @subjects << output
        output
      end

      def html_task(params, coords, options={})
        output = ''
        # Renders the task bar, with progress and late
        if coords[:bar_start] && coords[:bar_end]
          width = coords[:bar_end] - coords[:bar_start] - 2
          style = ""
          style << "top:#{params[:top]}px;"
          style << "left:#{coords[:bar_start]}px;"
          style << "width:#{width}px;"
          html_id = "task-todo-issue-#{options[:issue].id}" if options[:issue]
          html_id = "task-todo-version-#{options[:version].id}" if options[:version]
          content_opt = {:style => style,
                         :class => "#{options[:css]} task_todo",
                         :id => html_id}
          if options[:issue]
            rels = issue_relations(options[:issue])
            if rels.present?
              content_opt[:data] = {"rels" => rels.to_json}
            end
          end
          output << view.content_tag(:div, '&nbsp;'.html_safe, content_opt)
          if coords[:bar_late_end]
            width = coords[:bar_late_end] - coords[:bar_start] - 2
            style = ""
            style << "top:#{params[:top]}px;"
            style << "left:#{coords[:bar_start]}px;"
            style << "width:#{width}px;"
            output << view.content_tag(:div, '&nbsp;'.html_safe,
                                       :style => style,
                                       :class => "#{options[:css]} task_late")
          end
          if coords[:bar_progress_end]
            width = coords[:bar_progress_end] - coords[:bar_start] - 2
            style = ""
            style << "top:#{params[:top]}px;"
            style << "left:#{coords[:bar_start]}px;"
            style << "width:#{width}px;"
            html_id = "task-done-issue-#{options[:issue].id}" if options[:issue]
            html_id = "task-done-version-#{options[:version].id}" if options[:version]
            output << view.content_tag(:div, '&nbsp;'.html_safe,
                                       :style => style,
                                       :class => "#{options[:css]} task_done",
                                       :id => html_id)
          end
        end
        # Renders the markers
        if options[:markers]
          if coords[:start]
            style = ""
            style << "top:#{params[:top]}px;"
            style << "left:#{coords[:start]}px;"
            style << "width:15px;"
            output << view.content_tag(:div, '&nbsp;'.html_safe,
                                       :style => style,
                                       :class => "#{options[:css]} marker starting")
          end
          if coords[:end]
            style = ""
            style << "top:#{params[:top]}px;"
            style << "left:#{coords[:end] + params[:zoom]}px;"
            style << "width:15px;"
            output << view.content_tag(:div, '&nbsp;'.html_safe,
                                       :style => style,
                                       :class => "#{options[:css]} marker ending")
          end
        end
        # Renders the label on the right
        if options[:label]
          style = ""
          style << "top:#{params[:top]}px;"
          style << "left:#{(coords[:bar_end] || 0) + 8}px;"
          style << "width:15px;"
          output << view.content_tag(:div, options[:label],
                                     :style => style,
                                     :class => "#{options[:css]} label")
        end
        # Renders the tooltip
        if options[:issue] && coords[:bar_start] && coords[:bar_end]
          s = view.content_tag(:span,
                               view.render_issue_tooltip(options[:issue]).html_safe,
                               :class => "tip")
          style = ""
          style << "position: absolute;"
          style << "top:#{params[:top]}px;"
          style << "left:#{coords[:bar_start]}px;"
          style << "width:#{coords[:bar_end] - coords[:bar_start]}px;"
          style << "height:12px;"
          output << view.content_tag(:div, s.html_safe,
                                     :style => style,
                                     :class => "tooltip")
        end
        row_bottom = params[:top].to_i + 18
        rowstyle = ""
        rowstyle << "top:#{row_bottom}px;"
        rowstyle << "width:#{params[:g_width]}px;"
        output << view.content_tag(:div, '&nbsp;'.html_safe, :class => "time-row",:style => rowstyle)
        @lines << output
        output
      end
    end
  end
end
