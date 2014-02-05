module ZendeskAppsSupport

  class AppFile

    attr_reader :relative_path
    attr_reader :absolute_path

    def initialize(package, relative_path)
      @relative_path = relative_path
      @file = File.new(package.root.join(relative_path))
      @absolute_path = File.absolute_path @file.path
    end

    def read
      File.read @file.path
    end

    def =~(regex)
      @relative_path =~ regex
    end

    alias_method :to_s, :relative_path

    def method_missing(sym, *args, &block)
      if @file.respond_to?(sym)
        @file.call(sym, *args, &block)
      else
        super
      end
    end

    # Unless Ruby 1.9
    def respond_to?(sym, include_private = false)
      @file.respond_to?(sym, include_private) || super
    end

    # If Ruby 1.9
    def respond_to_missing?(sym, include_private = false)
      @file.send(:respond_to_missing?, sym, include_private) || super
    end

  end

end
