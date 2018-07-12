module SmartMerge 
  class UpdateService < SmartMerge::BaseService
    def execute
      if params[:base_branch] != smart_merge.base_branch[:name]
        source_sha = project.repository.find_branch(params[:base_branch]).target
        smart_merge.base_branch = { name: params[:base_branch], source_sha: source_sha }
      end

      add, del = get_change_source_branches
      smart_merge.source_branches = smart_merge.source_branches.delete_if{ |sb| del.include?(sb[:name]) } if del.present?
      add.each do |branch|
        smart_merge.source_branches << { name: branch, status: "PENDING" }.merge(smart_merge.branch_info(branch))
      end if add.present?

      if to_auto_merge?
        smart_merge.base_branch[:source_sha] = project.repository.find_branch(params[:base_branch]).target
        smart_merge.source_branches = smart_merge.source_branches.map do |branch|
          { name: branch[:name], status: "PENDING" }.merge(smart_merge.branch_info(branch[:name]))
        end
      end

      smart_merge.auto_merge = params[:auto_merge]
      smart_merge.save
    end

    private
    def get_change_source_branches
      old_branches = smart_merge.source_branches.map{ |sb| sb[:name] }
      new_branches = params[:source_branches]
      add = new_branches - old_branches
      del = old_branches - new_branches
      [add, del]
    end
    
    def to_auto_merge?
      !smart_merge.auto_merge && params[:auto_merge] 
    end
  end
end
