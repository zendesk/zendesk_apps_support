module ZendeskAppsSupport
  module FileLocations
    def files
      @files ||= Dir.chdir(root) do
        Dir['**/**'].select do |f|
          File.file?(f) && !f.start_with?('tmp/')
        end
      end
    end

    def asset_files
      @asset_files ||= files.select { |f| f.start_with?('assets/') }
    end

    def js_files
      @js_files ||= files.select { |f| f == 'app.js' || ( f.start_with?('lib/') && f.end_with?('.js') ) }
    end

    def lib_files
      @lib_files ||= js_files.select { |f| f =~ /^lib\// }
    end

    def template_files
      files.select { |f| f =~ /^templates\/.*\.hdbs$/ }
    end

    def translation_files
      files.select { |f| f.start_with?('translations/') }
    end
  end
end
