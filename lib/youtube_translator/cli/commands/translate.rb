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
          log "Fetching transcript (#{@options[:source_lang]}) for: #{video_url}"

          segments = fetcher.fetch(@options[:source_lang], prefer_auto: @options[:prefer_auto])
          log "Found #{segments.size} segments"

          log_translation_method
          translated = translator.translate_segments(segments)

          output = format_output(translated)
          write_output(output)
        end

        private

        def log_translation_method
          log "Translating with #{effective_provider} (#{effective_model}) from #{@options[:source_lang]} to #{@options[:target_lang]}..."
        end
      end
    end
  end
end
