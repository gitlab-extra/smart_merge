module SmartMerge 
  class TriggerService < SmartMerge::BaseService
    def execute
      if smart_merge
        SmartMerge::MergeService.new(project: project, user: user, smart_merge: smart_merge).execute
      elsif params[:branch_name]
        SmartMergeSetting.where(project_id: project.id).each do |smart_merge|
          source_branch = smart_merge.find_source_branch(params[:branch_name])
          if source_branch.present?
            source_branch.merge!(smart_merge.branch_info(source_branch[:name]))
            smart_merge.update_source_branch(source_branch)
          end
          if smart_merge.base_branch[:name] == params[:branch_name]
            smart_merge.base_branch[:source_sha] = project.repository.find_branch(params[:branch_name]).target
            smart_merge.save
          end
          if source_branch || smart_merge.base_branch[:name] == params[:branch_name]
            SmartMerge::MergeService.new(project: project, user: user, smart_merge: smart_merge, params: { trigger: "push" }).execute
          end
        end
      end
    end
  end
end
