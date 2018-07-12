module SmartMerge 
  class CheckService < SmartMerge::BaseService
    def execute
      conflicts = []
      branches = [smart_merge.base_branch].concat(smart_merge.source_branches_ordered)
      branches.each_with_index do |branch, index|
        next_index = index + 1
        branch_sha = project.repository.commit(branch[:name]).id
        branches.slice(next_index..-1).each do |other_branch|
          other_branch_sha = project.repository.commit(other_branch[:name]).id
          merge_index = project.repository.rugged.merge_commits(branch_sha, other_branch_sha)
          if merge_index.conflicts?
            files = merge_index.conflicts.map{ |conflic| conflic[:ancestor] && conflic[:ancestor][:path] }.compact
            conflict_branches = [ branch[:name], other_branch[:name] ]
            conflicts << { branches: conflict_branches, files: files }
          end
        end
      end
      smart_merge.update(conflicts: conflicts)
    end
  end
end
