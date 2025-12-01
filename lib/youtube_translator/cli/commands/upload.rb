# frozen_string_literal: true

require 'yaml'

module YouTubeTranslator
  module CLI
    module Commands
      # Uploads captions to YouTube
      class Upload < Base
        LANGUAGES_FILE = File.join(YouTubeTranslator::APP_ROOT, 'config', 'languages.yml')

        LANG_PATTERN = /(?:translated_)?([a-z]{2}(?:-[A-Z]{2,4})?)\./.freeze
        TIMESTAMP_PATTERN = /^\[(\d{2}):(\d{2})\]\s*(.*)$/.freeze
        DEFAULT_DURATION = 3.0

        def execute
          validate_args!

          uploader = YouTubeTranslator::YoutubeUploader.new
          uploader.authenticate!

          content = prepare_content
          result = uploader.upload_caption(video_id, language, content, upload_options)
          display_result(result)
        end

        private

        def validate_args!
          raise Error, 'Usage: upload <video_id> <file_or_language>' if @args.length < 2
        end

        def video_id
          @video_id ||= VideoIdExtractor.extract(@args[0])
        end

        def file_or_lang
          @args[1]
        end

        def language
          # For upload, use explicitly passed -t option, otherwise detect from file/arg
          # Don't use config default target_lang as it's meant for translation, not upload
          @language ||= explicit_target_lang || detect_language
        end

        def explicit_target_lang
          # Only use target_lang if it was explicitly passed via -t flag
          # Check if it differs from config default (meaning user specified it)
          config_default = YouTubeTranslator.configuration.target_lang
          opt = @options[:target_lang]
          opt if opt && opt != config_default
        end

        def detect_language
          return extract_lang_from_filename if File.exist?(file_or_lang)

          file_or_lang
        end

        def extract_lang_from_filename
          match = File.basename(file_or_lang).match(LANG_PATTERN)
          match ? match[1] : file_or_lang
        end

        def prepare_content
          raw_content = load_content
          convert_to_srt(raw_content)
        end

        def load_content
          path = content_file_path
          raise Error, "File not found: #{file_or_lang}" unless path

          File.read(path, encoding: 'UTF-8')
        end

        def content_file_path
          [file_or_lang, review_file_path].find { |p| File.exist?(p) }
        end

        def review_file_path
          provider = effective_provider
          File.join('reviews', provider, video_id, "translated_#{language}.txt")
        end

        def convert_to_srt(content)
          # If already SRT format, return as-is
          return content if srt_format?(content)

          # Convert timestamped text to SRT
          segments = parse_timestamped_text(content)
          build_srt(segments)
        end

        def srt_format?(content)
          # SRT starts with a number, then timestamp line with -->
          content.strip.match?(/\A\d+\r?\n\d{2}:\d{2}:\d{2},\d{3}\s*-->\s*\d{2}:\d{2}:\d{2},\d{3}/)
        end

        def parse_timestamped_text(content)
          lines = content.lines.map(&:strip).reject(&:empty?)
          segments = []

          lines.each do |line|
            match = line.match(TIMESTAMP_PATTERN)
            next unless match

            minutes, seconds, text = match.captures
            start_seconds = minutes.to_i * 60 + seconds.to_i

            segments << { start: start_seconds.to_f, text: text.strip }
          end

          calculate_durations(segments)
        end

        def calculate_durations(segments)
          segments.each_with_index do |seg, idx|
            next_seg = segments[idx + 1]
            seg[:duration] = if next_seg
                               [next_seg[:start] - seg[:start], DEFAULT_DURATION].min
                             else
                               DEFAULT_DURATION
                             end
          end

          segments
        end

        def build_srt(segments)
          segments.each_with_index.map do |seg, idx|
            start_time = format_srt_timestamp(seg[:start])
            end_time = format_srt_timestamp(seg[:start] + seg[:duration])

            "#{idx + 1}\n#{start_time} --> #{end_time}\n#{seg[:text]}\n"
          end.join("\n")
        end

        def format_srt_timestamp(seconds)
          hours = (seconds / 3600).to_i
          mins = ((seconds % 3600) / 60).to_i
          secs = (seconds % 60).to_i
          millis = ((seconds % 1) * 1000).to_i

          Kernel.format('%02d:%02d:%02d,%03d', hours, mins, secs, millis)
        end

        def upload_options
          { name: caption_name, draft: @options[:draft] }
        end

        def caption_name
          @options[:caption_name] || "#{language_name} (YouTube Translator)"
        end

        def language_name
          language_names.fetch(language, language.upcase)
        end

        def language_names
          @language_names ||= YAML.load_file(LANGUAGES_FILE)
        end

        def display_result(result)
          return puts 'Caption uploaded.' unless result&.dig('id')

          display_success(result)
        end

        def display_success(result)
          puts '✓ Caption uploaded successfully!'
          puts "  Caption ID: #{result['id']}"
          puts "  Language: #{result.dig('snippet', 'language')}"
          puts "  Name: #{result.dig('snippet', 'name')}"
          puts "  Draft: #{result.dig('snippet', 'isDraft')}"
        end
      end
    end
  end
end
