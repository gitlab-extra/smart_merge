module SmartMerge 
  class CreateService < SmartMerge::BaseService
    def execute
      smart_merge = SmartMergeSetting.new(project_id: @project.id, target_branch: params[:target_branch], creator: @user.id) 

      smart_merge.source_branches = params[:source_branches].map do |branch|
        recent_commit = @project.repository.commits(branch).first
        { name: branch, status: "PENDING", source_sha: recent_commit.id, author: recent_commit.author_name, update_at: recent_commit.committed_date.strftime("%Y-%m-%d %H:%M:%S") }
      end

      source_sha = @project.repository.find_branch(params[:base_branch]).target
      smart_merge.base_branch = { name: params[:base_branch], source_sha: source_sha }

      smart_merge.save
      smart_merge
    end
  end
end
