# frozen_string_literal: true

module YouTubeTranslator
  module CLI
    module Commands
      # Fetches and translates transcript
      class Translate < Base
        def validate!
          require_video_url!
        end

        def run
          segments = fetch_segments
          translated = translate_segments(segments)
          write_output(format_output(translated))
        end

        private

        def fetch_segments
          log "Fetching transcript (#{@options[:source_lang]}) for: #{video_url}"
          segments = fetcher.fetch(@options[:source_lang], prefer_auto: @options[:prefer_auto])
          log "Found #{segments.size} segments"
          segments
        end

        def translate_segments(segments)
          log_translation_method
          translator.translate_segments(segments)
        end

        def log_translation_method
          log "Translating with #{effective_provider} (#{effective_model}) " \
              "from #{@options[:source_lang]} to #{@options[:target_lang]}..."
        end
      end
    end
  end
end
