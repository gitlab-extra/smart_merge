# SmartMerge

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/smart_merge`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'smart_merge', git: 'https://github.com/gitlab-extra/smart_merge'
```

And then execute:

    $ bundle

And then execute:

    $ bundle exec rails generate smart_merge:install
    $ bundle exec rake db:migrate

## Usage

Assume your project's repository has multiple branches of master,test1,test2,test3, you can run the command to create a smart_merge_setting:

    $  params = {"target_branch"=>"LM/light", "base_branch"=>"master", "source_branches"=>["test3", "test1", "test2"], "auto_merge"=>true}
    $  sm = SmartMerge::CreateService.new(project: your_project, user: you, params: params).execute
    
And if have conflicts between the base_branch and source_branches, you can see the conflicts by:

    $  sm.conflicts
    $  => [{:branches=>["master", "test2"], :files=>["1.txt"]}, {:branches=>["test2", "test3"], :files=>["1.txt"]}]

And if no conflicts, the project will create target_branch(LM/light) from master and merge the source_branches(["test3", "test1", "test2"]).

And after the base_branch or the source_branches update, you can remerge by:
    
    $  SmartMerge::TriggerService.new(project: your_project, user: you, params: { branch_name: updated_branch_name }).execute

And if you want to remerge after push code，you can add the following code to the app/workers/post_receive.rb:

    $  LightMerge.auto_merge_by_ref(post_received.project, @user, ref)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/gitlab-extra/smart_merge.

