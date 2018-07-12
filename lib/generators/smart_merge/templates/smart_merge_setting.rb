class SmartMergeSetting < ActiveRecord::Base
  belongs_to :project

  serialize :base_branch
  serialize :source_branches
  serialize :conflicts

  validates :base_branch, presence: true
  validate :validate_source_branches

  before_create :validate_target_branches
  after_create :create_target_branch

  STATUS_LIST = {'unchecked' => 0, 'success' => 1, 'failed' => 2}

  def self.auto_merge_by_ref(project, user, ref)
    branch_name = ref.match(/refs\/heads\/(.+)/)[1]
    SmartMerge::TriggerService.new(project: project, user: user, params: { branch_name: branch_name }).execute
  end

  def validate_target_branches
    if self.project.repository.branch_names.include?(self.target_branch)
      message = "Target branch was existed!"
    end

    light_merges = SmartMergeSetting.where(project_id: self.project_id, target_branch: self.target_branch)
    if light_merges.present?
      message = "Target branch was used by other light merge"
      errors.add :target_branch_conflict, message if message.present?
      return false
    end
  end

  def validate_source_branches
    if source_branches.blank?
      errors.add :source_branches_blank, "source branches can not be blank"
      return false
    end
    delete_branches = source_branches.reject{ |b| project.repository.branch_names.include?(b[:name]) }
    if delete_branches.present?
      errors.add :source_branch_not_exist, "#{delete_branches.join(" ")} was not exist"
      return false
    end
  end

  def source_branches_ordered
    self[:source_branches].sort_by{|sb| sb[:name]}
  end

  def check_if_can_be_merged
    require_merge_branches.inject([]) do |arr, branch|
      unless project.repository.can_be_merged?(branch[:source_sha], target_branch)
        branch[:status] = "FAILURE"
        update_source_branch(branch)
        arr << branch
      end
      arr 
    end
  end

  def user
    User.find(creator)
  end

  def recent_update_source_branch
    source_branches.sort_by{|sb| sb[:update_at]}.last
  end

  def recent_update_by
    recent_update_source_branch.try(:[], :author)
  end

  def display_status
    case 
    when merging? then "Merging"
    when merged? then "Merged"
    when conflict? then "Conflict"
    end
  end

  def merging?
    source_branches.select{ |branch| ["PENDING", "MERGING"].include?(branch[:status]) }.present?
  end
  
  def merged?
    source_branches.select{ |branch| branch[:status] != "MERGED" }.blank?
  end

  def conflict?
    source_branches.select{ |branch| ["CONFLICT", "UNMERGE"].include?(branch[:status]) }.present?
  end

  def find_branch(name)
    light_merge.project.repository.find_branch(name)
  end

  def can_merge?
    source_branches.select do |branch|
      light_merge.find_branch(branch[:name]).target != branch[:source_sha]
    end.present?
  end

  def can_branch_merge?(name)
    light_merge.find_branch(name).target != branch[:source_sha]
  end

  def to_pending(branch)
    source_branch = source_branches.select{ |sb| sb[:name] == branch }[0]
    if source_branch
      source_branch[:status] = "PENDING"
      update_source_branch(source_branch)
    end
  end

  def source_branch_forward(name)
    if name.present?
      source_branch = find_source_branch(name)
      update_source_branch(source_branch.merge(branch_info(name)).merge(status: "PENDING")) if source_branch
    else
      sbs = source_branches.map do |sb|
        sb.merge(branch_info(sb[:name]).merge(status: "PENDING"))
      end
      update(source_branches: sbs)
    end
  end

  def merge_commit_message(branch)
    "Merge branch '#{branch}' into '#{target_branch}'"
  end

  def recent_merged_message
    branch = source_branches.select{ |sb| sb[:status] == "SUCCESS" }.sort_by{|sb| sb[:update_at]}.last
    return "UNMERGED!" unless branch
    "#{branch[:name]} Was Merged Into #{target_branch} At #{branch[:update_at]}!"
  end

  def failure_branches
    source_branches.select{ |sb| sb[:status] == "FAILURE" }
  end

  def update_source_branch(branch)
    branches = source_branches.delete_if{ |sb| sb[:name] == branch[:name] }
    branches.push(branch)
    update(source_branches: branches)
  end

  def branch_info(name)
    recent_commit = project.repository.commits(name).first
    { source_sha: recent_commit.id, author: recent_commit.author_name, update_at: recent_commit.committed_date.strftime("%Y-%m-%d %H:%M:%S") }
  end

  def find_source_branch(name)
    source_branches.select{ |sb| sb[:name] == name }[0]
  end

  def updated_source_branches
    source_branches.select do |source_branch|
      target_sha = project.repository.find_branch(source_branch[:name]).target
      target_sha != source_branch[:source_sha]
    end
  end

  def tmp_ref
    "refs/light_merge/#{target_branch}"
  end

  def in_locked_state
    begin
      Timeout.timeout(300) do 
        loop do
          break if reload.status != STATUS_LIST["unchecked"]
          sleep 5
        end
      end
      update(status: STATUS_LIST["unchecked"])
      result = yield
      update(status: STATUS_LIST["success"]) if status == STATUS_LIST["unchecked"]
      result
    rescue 
      update(status: STATUS_LIST["failed"]) 
      false
    end
  end

  def create_target_branch
    CreateBranchService.new(self.project, User.find(self.creator)).execute(self.target_branch, self.base_branch[:source_sha])
  end
end
