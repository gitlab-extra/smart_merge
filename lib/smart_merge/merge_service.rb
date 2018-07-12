module SmartMerge 
  class MergeService < SmartMerge::BaseService
    def execute
      return to_failure unless check
      return if !smart_merge.auto_merge && params[:trigger] == "push"
      smart_merge.in_locked_state do
        begin
          to_pending
          to_merge
          to_success
        rescue
          to_failure
        end
      end
    end

    private
    def check
      SmartMerge::CheckService.new(project: project, user: user, smart_merge: smart_merge).execute
      return true if smart_merge.conflicts.blank?
      conflict_branches = smart_merge.conflicts.map{ |conflic| conflic[:branches] }.flatten
      source_branches = smart_merge.source_branches.map do |source_branch|
        source_branch[:status] = conflict_branches.include?(source_branch[:name]) ? "CONFLICT" : "UNMERGE"
        source_branch
      end
      smart_merge.update(source_branches: source_branches)
      false
    end

    def to_pending 
      smart_merge.update(status: SmartMergeSetting::STATUS_LIST["unchecked"])
      source_branches = smart_merge.source_branches.map do |source_branch|
        source_branch[:status] == "PENDING"
        source_branch
      end
      smart_merge.update(source_branches: source_branches)

      delete_tmp_ref
      rugged.references.create(smart_merge.tmp_ref, smart_merge.base_branch[:source_sha])
    end

    def to_merge
      smart_merge.source_branches_ordered.each do |branch|
        branch[:status] = "MERGING"
        smart_merge.update_source_branch(branch)
        unless commit(branch)
          to_unmerge
          break
        end
      end
    end

    def to_unmerge
      source_branches = smart_merge.source_branches.map do |source_branch|
        source_branch[:status] == "UNMERGE"
        source_branch
      end
      smart_merge.update(source_branches: source_branches)
    end

    def to_success
      if smart_merge.conflict?
        to_failure
      else
        if !project.repository.branch_exists?(smart_merge.target_branch)
          CreateBranchService.new(project, user).execute(smart_merge.target_branch, smart_merge.base_branch[:source_sha])
        end
        ref = Gitlab::Git::BRANCH_REF_PREFIX + smart_merge.target_branch
        GitOperationService.new(user, project.repository).update_ref_in_hooks(ref, tmp_branch_sha, smart_merge.base_branch[:source_sha])
        delete_tmp_ref
      end
    end

    def commit(branch)
      begin
        tmp_branch_sha = project.repository.commit(smart_merge.tmp_ref).id
        if tmp_branch_sha == branch[:source_sha] || project.repository.is_ancestor?(branch[:source_sha], tmp_branch_sha)
          branch[:status] = "MERGED"
        else
          if Rugged::Commit.create(rugged, merge_options(branch))
            branch[:status] = "MERGED"
          else
            branch[:status] = "UNMERGE"
          end
        end
      rescue => e
        branch[:status] = "UNMERGE"
        Rails.logger.error(e.message)
      end

      smart_merge.update_source_branch(branch)
      return branch[:status] == "MERGED"
    end

    def merge_options(branch)
      committer = project.repository.user_to_committer(user)
      merge_index = rugged.merge_commits(tmp_branch_sha, branch[:source_sha])
      {
        parents: [tmp_branch_sha, branch[:source_sha]],
        message: params[:commit_message] || smart_merge.merge_commit_message(branch[:name]),
        tree: merge_index.write_tree(rugged),
        update_ref: smart_merge.tmp_ref,
        author: committer,
        committer: committer
      }
    end

    def rugged
      project.repository.rugged
    end

    def tmp_branch_sha
      project.repository.commit(smart_merge.tmp_ref).id
    end

    def delete_tmp_ref
      if project.repository.commit(smart_merge.tmp_ref)
        rugged.references.delete(smart_merge.tmp_ref)
      end
    end

    def to_failure
      smart_merge.update(status: SmartMergeSetting::STATUS_LIST["failed"])
      target_branch = project.repository.find_branch(smart_merge.target_branch)
      if target_branch && target_branch.target != smart_merge.base_branch[:source_sha]
        ref = Gitlab::Git::BRANCH_REF_PREFIX + smart_merge.target_branch
        GitOperationService.new(user, project.repository).send(:update_ref, ref, smart_merge.base_branch[:source_sha], nil)
      elsif target_branch.nil?
        CreateBranchService.new(project, user).execute(smart_merge.target_branch, smart_merge.base_branch[:source_sha])
      end
      delete_tmp_ref
      Notify.conflict_smart_merge_email(user.id, smart_merge.id).deliver_now
    end
  end
end
