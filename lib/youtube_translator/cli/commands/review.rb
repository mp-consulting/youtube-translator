# frozen_string_literal: true

module YouTubeTranslator
  module CLI
    module Commands
      # Manages review workflow (review and translate-reviewed)
      class Review < Base
        def validate!
          require_video_url!
        end

        def run
          if translate_reviewed?
            run_translate_reviewed
          else
            run_review
          end
        end

        private

        def translate_reviewed?
          @translate_reviewed
        end

        def run_review
          log "Fetching transcript (#{@options[:source_lang]}) for: #{video_url}"

          segments = fetcher.fetch(@options[:source_lang])
          log "Found #{segments.size} segments"

          log_translation_method
          translated = translator.translate_segments(segments)
          log 'Translation complete!'

          review_manager = build_review_manager
          review_file = review_manager.save_for_review(segments, translated)

          log_review_files(review_manager, review_file)
        end

        def run_translate_reviewed
          video_id = video_url

          review_manager = ReviewManager.new(video_id, review_options)
          segments = review_manager.load_reviewed_segments

          log "Loading reviewed transcript for: #{video_id}"
          log "Found #{segments.size} segments"

          log_translation_method
          translated = translator.translate_segments(segments)

          output = format_output(translated)
          write_output(output)
        end

        def build_review_manager
          ReviewManager.new(extract_video_id, review_options)
        end

        def extract_video_id
          video_url.match(/([a-zA-Z0-9_-]{11})/)[1]
        end

        def review_options
          {
            source_lang: @options[:source_lang],
            target_lang: @options[:target_lang],
            provider: effective_provider,
            include_timestamps: @options[:timestamps]
          }
        end

        def log_review_files(manager, review_file)
          log "\nOriginal transcript saved"
          log 'Translated transcript saved'
          log "Review file saved to: #{review_file}"
          log "\nOpen the review file to edit translations."
        end

        def log_translation_method
          log "Translating with #{effective_provider} (#{effective_model}) from #{@options[:source_lang]} to #{@options[:target_lang]}..."
        end

        class << self
          def for_translate_reviewed(args, options)
            cmd = new(args, options)
            cmd.instance_variable_set(:@translate_reviewed, true)
            cmd
          end
        end
      end
    end
  end
end
