require 'rails/generators/base'

module SmartMerge
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      def copy_initializer_file
        copy_file "smart_merge_setting.rb", "app/models/smart_merge_setting.rb"
        copy_file "create_smart_merge_settings.rb", "db/migrate/#{Time.now.strftime('%Y%m%d%H%M%S')}_create_smart_merge_settings.rb"
      end
    end
  end
end
