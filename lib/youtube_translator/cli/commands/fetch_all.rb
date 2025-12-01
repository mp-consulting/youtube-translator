# frozen_string_literal: true

require 'fileutils'

module YouTubeTranslator
  module CLI
    module Commands
      # Fetches all available transcripts and saves them locally
      class FetchAll < Base
        TRANSCRIPTS_DIR = 'transcripts'
        EXTENSIONS = { srt: 'srt', vtt: 'vtt', json: 'json' }.freeze

        def validate!
          require_video_url!
        end

        def run
          log "Fetching all transcripts for: #{video_url}"

          languages = fetcher.available_languages
          return log('No captions available for this video') if languages.empty?

          log "Found #{languages.size} transcript(s)"
          ensure_output_dir

          languages.each { |lang| fetch_and_save(lang) }

          log "\nAll transcripts saved to: #{output_dir}"
        end

        private

        def video_id
          @video_id ||= VideoIdExtractor.extract(video_url)
        end

        def output_dir
          @output_dir ||= File.join(Dir.pwd, TRANSCRIPTS_DIR, video_id)
        end

        def ensure_output_dir
          FileUtils.mkdir_p(output_dir)
        end

        def fetch_and_save(lang)
          filename = build_filename(lang)
          filepath = File.join(output_dir, filename)

          log "  Fetching #{language_description(lang)}..."

          segments = fetcher.fetch(lang.code, prefer_auto: lang.auto_generated)
          output = format_output(segments)
          File.write(filepath, output, encoding: 'UTF-8')

          log "    -> #{filename} (#{segments.size} segments)"
        rescue StandardError => e
          log "    -> Failed: #{e.message}"
        end

        def build_filename(lang)
          suffix = lang.auto_generated ? '_auto' : ''
          "#{lang.code}#{suffix}.#{format_extension}"
        end

        def language_description(lang)
          auto_label = lang.auto_generated ? ' [auto]' : ''
          "#{lang.name} (#{lang.code})#{auto_label}"
        end

        def format_extension
          EXTENSIONS.fetch(@options[:format], 'txt')
        end
      end
    end
  end
end
