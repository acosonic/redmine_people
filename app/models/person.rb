class Person < User
  unloadable
  self.inheritance_column = :_type_disabled

  belongs_to :department

  include Redmine::SafeAttributes
  
  # user category
  STAFF = 0
  CUSTOMER = 1
  PARTNER = 2
  
  GENDERS = [[l(:label_people_male), 0], [l(:label_people_female), 1]]
  CATEGORIES = [[l(:label_category_staff), 0], [l(:label_category_customer), 1],[l(:label_category_partner), 2]]
  
  scope :staff, lambda { where(:category => STAFF) }
  
  scope :in_department, lambda {|department|
    department_id = department.is_a?(Department) ? department.id : department.to_i
    { :conditions => {:department_id => department_id, :type => "User"} }
  }
  scope :not_in_department, lambda {|department|
    department_id = department.is_a?(Department) ? department.id : department.to_i
    { :conditions => ["(#{User.table_name}.department_id != ?) OR (#{User.table_name}.department_id IS NULL)", department_id] }
  }  

  scope :seach_by_name, lambda {|search| {:conditions =>   ["(LOWER(#{Person.table_name}.firstname) LIKE ? OR 
                                                                    LOWER(#{Person.table_name}.lastname) LIKE ? OR 
                                                                    LOWER(#{Person.table_name}.middlename) LIKE ? OR 
                                                                    LOWER(#{Person.table_name}.login) LIKE ? OR 
                                                                    LOWER(#{Person.table_name}.mail) LIKE ?)", 
                                                                  search.downcase + "%",
                                                                  search.downcase + "%",
                                                                  search.downcase + "%",
                                                                  search.downcase + "%",
                                                                  search.downcase + "%"] }}

  validates_uniqueness_of :firstname, :scope => [:lastname, :middlename]

  safe_attributes 'phone', 
                  'address',
                  'skype',
                  'birthday',
                  'job_title',
                  'company',
                  'middlename',
                  'gender',
                  'twitter',
                  'facebook',
                  'linkedin',
                  'department_id',
                  'background',
                  'appearance_date'


  def phones                            
    @phones || self.phone ? self.phone.split( /, */) : []
  end  

  def type
    'User'
  end

  def email
    self.mail
  end

  def project
    nil
  end

  def next_birthday
    return if birthday.blank?
    year = Date.today.year
    mmdd = birthday.strftime('%m%d')
    year += 1 if mmdd < Date.today.strftime('%m%d')
    mmdd = '0301' if mmdd == '0229' && !Date.parse("#{year}0101").leap?
    return Date.parse("#{year}#{mmdd}")
  end

  def self.next_birthdays(limit = 10)
    Person.where("users.birthday IS NOT NULL").sort_by(&:next_birthday).first(limit)
  end

  def age
    return nil if birthday.blank?
    now = Time.now
    age = now.year - birthday.year - (birthday.to_time.change(:year => now.year) > now ? 1 : 0)
  end

  def editable_by?(usr, prj=nil)
    true    
    # usr && (usr.allowed_to?(:edit_people, prj) || (self.author == usr && usr.allowed_to?(:edit_own_invoices, prj))) 
    # usr && usr.logged? && (usr.allowed_to?(:edit_notes, project) || (self.author == usr && usr.allowed_to?(:edit_own_notes, project)))
  end

  def visible?(usr=nil)
    true
  end

  def attachments_visible?(user=User.current)
    true
  end
#GMO begin
  def member_projects
    @member_projects ||= self.memberships.where("#{Project.table_name}.status = #{Project::STATUS_ACTIVE}").all
  end
  # The earliest start date assgined to this person based on it's  allocation
  def allocation_from_date
    @allocation_from_date ||= self.memberships.minimum(:from_date,:conditions => "#{Project.table_name}.status = #{Project::STATUS_ACTIVE}")
  end
  # The latest to date of assigned to this person based on it's allocation
  def allocation_to_date
    @allocation_to_date ||= self.memberships.maximum(:to_date,:conditions => "#{Project.table_name}.status = #{Project::STATUS_ACTIVE}")
  end
  
  def assigned_dates
    terms=[]
    if person_memberships?
      
    end
    terms
  end
#GMO end    
end
