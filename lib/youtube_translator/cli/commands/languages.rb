# frozen_string_literal: true

module YouTubeTranslator
  module CLI
    module Commands
      # Lists available languages for a video
      class Languages < Base
        def validate!
          require_video_url!
        end

        def run
          languages = fetcher.available_languages
          return log('No captions available for this video') if languages.empty?

          log 'Available languages:'
          languages.each { |lang| log format_language(lang) }
        end

        private

        def format_language(lang)
          auto = lang.auto_generated ? ' (auto-generated)' : ''
          "  #{lang.code}: #{lang.name}#{auto}"
        end
      end
    end
  end
end
