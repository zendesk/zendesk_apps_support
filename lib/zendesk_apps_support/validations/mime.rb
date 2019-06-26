# frozen_string_literal: true

require 'mimemagic'

module ZendeskAppsSupport
  module Validations
    module Mime
      UNSUPPORTED_MIME_TYPES = %w[
        vnd.rar rar zip gzip pdf doc docx avi bin bz bz2 csh sh jar mp3 mpeg odt pptx ppt xls xlsx 7z
      ].freeze

      class << self
        def call(package)
          unsupported_files =
            package.files.find_all { |app_file| block_listed?(app_file) }.map(&:relative_path)

          [mime_type_warning(unsupported_files)] if unsupported_files.any?
        end

        private

        def block_listed?(app_file)
          mime_type = MimeMagic.by_magic(app_file.read)

          content_subtype = mime_type.subtype if mime_type
          extension_name = app_file.extension.delete('.')

          ([content_subtype, extension_name] & UNSUPPORTED_MIME_TYPES).any?
        end

        def mime_type_warning(file_names)
          ValidationError.new(
            :unsupported_mime_type_detected,
            file_names: file_names.join(', '),
            count: file_names.count
          )
        end
      end
    end
  end
end
