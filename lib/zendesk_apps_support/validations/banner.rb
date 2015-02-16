require 'image_size'

module ZendeskAppsSupport
  module Validations
    module Banner
      BANNER_WIDTH = 830
      BANNER_HEIGHT = 200

      class <<self
        def call(package)
          File.open(package.file_path('assets/banner.png'), 'rb') do |fh|
            begin
              image = ImageSize.new(fh)

              unless image.format == :png
                return [ValidationError.new('banner.invalid_format')]
              end

              unless (image.width == BANNER_WIDTH && image.height == BANNER_HEIGHT) ||
                     (image.width == 2 * BANNER_WIDTH && image.height == 2 * BANNER_HEIGHT)
                return [ValidationError.new('banner.invalid_size', required_banner_width: BANNER_WIDTH,
                                                                   required_banner_height: BANNER_HEIGHT)]
              end
            rescue
              return [ValidationError.new('banner.invalid_format')]
            end
          end
          []
        end
      end
    end
  end
end
