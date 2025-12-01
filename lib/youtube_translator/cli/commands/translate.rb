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

          segments = fetcher.fetch(@options[:source_lang])
          log "Found #{segments.size} segments"

          log_translation_method
          translated = translator.translate_segments(segments)
          log "\n" if @options[:use_chatgpt]

          output = format_output(translated)
          write_output(output)
        end

        private

        def log_translation_method
          if @options[:use_chatgpt]
            model = @options[:model] || YouTubeTranslator.configuration.openai_model
            log "Translating with ChatGPT (#{model}) from #{@options[:source_lang]} to #{@options[:target_lang]}..."
          else
            log "Translating from #{@options[:source_lang]} to #{@options[:target_lang]}...\n\n"
          end
        end
      end
    end
  end
end
