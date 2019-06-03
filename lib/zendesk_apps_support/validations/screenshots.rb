# frozen_string_literal: true

require 'image_size'

module ZendeskAppsSupport
  module Validations
    module Screenshots
      MAX_FILES = 3
      SCREENSHOT_WIDTH = 1024
      SCREENSHOT_HEIGHT = 768

      class << self
        def call(package)
          errors = []
          screenshot_paths = Dir["#{package.path_to('assets')}/*"].grep(/screenshot-\d.png$/)
          file_count = screenshot_paths.count
          if file_count > MAX_FILES
            errors << ValidationError.new('screenshots.excessive_files',
                                          file_count: file_count,
                                          supported_count: MAX_FILES)
          end

          screenshot_paths.each do |path|
            screenshot = ImageSize.new(File.open(path))
            next if screenshot.width == SCREENSHOT_WIDTH && screenshot.height == SCREENSHOT_HEIGHT
            errors << ValidationError.new('screenshots.invalid_size',
                                          file: File.basename(path),
                                          required_screenshot_width: SCREENSHOT_WIDTH,
                                          required_screenshot_height: SCREENSHOT_HEIGHT)
          end
          errors
        end
      end
    end
  end
end
