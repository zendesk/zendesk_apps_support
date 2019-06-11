# frozen_string_literal: true

module ZendeskAppsSupport
  class AppFile
    attr_reader :relative_path
    attr_reader :absolute_path

    def initialize(package, relative_path)
      @relative_path = relative_path
      @file = File.new(package.path_to(relative_path))
      @absolute_path = File.absolute_path @file.path
    end

    def read
      File.read @file.path
    end

    def extension
      File.extname relative_path
    end

    def =~(regex)
      relative_path =~ regex
    end

    def match(regex)
      self =~ regex
    end

    alias_method :to_s, :relative_path

    def method_missing(sym, *args, &block)
      if @file.respond_to?(sym)
        @file.call(sym, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(sym, include_private = false)
      @file.send(:respond_to_missing?, sym, include_private) || super
    end
  end
end
