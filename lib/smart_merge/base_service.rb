module SmartMerge
  class BaseService
    attr_accessor :project, :user, :params, :smart_merge

    def initialize(project: nil, user: nil, smart_merge: nil, params: {})
      @project, @user, @smart_merge, @params = project, user, smart_merge, params
    end
  end
end
