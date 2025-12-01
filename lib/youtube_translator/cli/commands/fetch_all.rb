# frozen_string_literal: true

require 'fileutils'

module YouTubeTranslator
  module CLI
    module Commands
      # Fetches all available transcripts and saves them locally
      class FetchAll < Base
        TRANSCRIPTS_DIR = 'transcripts'

        def validate!
          require_video_url!
        end

        def run
          log "Fetching all transcripts for: #{video_url}"

          languages = fetcher.available_languages
          if languages.empty?
            log 'No captions available for this video'
            return
          end

          log "Found #{languages.size} transcript(s)"
          ensure_output_dir

          languages.each do |lang|
            fetch_and_save(lang)
          end

          log "\nAll transcripts saved to: #{output_dir}"
        end

        private

        def video_id
          @video_id ||= VideoIdExtractor.extract(video_url)
        end

        def output_dir
          File.join(Dir.pwd, TRANSCRIPTS_DIR, video_id)
        end

        def ensure_output_dir
          FileUtils.mkdir_p(output_dir)
        end

        def fetch_and_save(lang)
          suffix = lang.auto_generated ? '_auto' : ''
          filename = "#{lang.code}#{suffix}.#{format_extension}"
          filepath = File.join(output_dir, filename)

          log "  Fetching #{lang.name} (#{lang.code})#{lang.auto_generated ? ' [auto]' : ''}..."

          segments = fetcher.fetch(lang.code, prefer_auto: lang.auto_generated)
          output = format_output(segments)
          File.write(filepath, output, encoding: 'UTF-8')

          log "    -> #{filename} (#{segments.size} segments)"
        rescue StandardError => e
          log "    -> Failed: #{e.message}"
        end

        def format_extension
          case @options[:format]
          when :srt then 'srt'
          when :vtt then 'vtt'
          when :json then 'json'
          else 'txt'
          end
        end
      end
    end
  end
end
