# frozen_string_literal: true

module YouTubeTranslator
  module CLI
    module Commands
      # Fetches and displays transcript
      class Fetch < Base
        def validate!
          require_video_url!
        end

        def run
          log "Fetching transcript for: #{video_url}"

          segments = fetcher.fetch(source_lang, prefer_auto: @options[:prefer_auto])

          log "Found #{segments.size} segments#{lang_suffix}\n\n"

          output = format_output(segments)
          write_output(output)
        end

        private

        def source_lang
          @options[:source_lang]
        end

        def lang_suffix
          lang = source_lang
          lang ? " (#{lang})" : ''
        end
      end
    end
  end
end
