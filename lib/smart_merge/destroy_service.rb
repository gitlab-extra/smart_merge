module SmartMerge
  class DestroyService < SmartMerge::BaseService
    def execute
      unless params[:remain_target]
        DeleteBranchService.new(project, user).execute(smart_merge.target_branch)
      end
      smart_merge.destroy
    end
  end
end
