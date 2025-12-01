# frozen_string_literal: true

module YouTubeTranslator
  module CLI
    module Commands
      # Uploads captions to YouTube
      class Upload < Base
        LANGUAGE_NAMES = {
          'en' => 'English', 'fr' => 'French', 'es' => 'Spanish',
          'de' => 'German', 'it' => 'Italian', 'pt' => 'Portuguese',
          'pt-BR' => 'Portuguese (Brazil)', 'ja' => 'Japanese',
          'ko' => 'Korean', 'zh' => 'Chinese',
          'zh-Hans' => 'Chinese (Simplified)',
          'zh-Hant' => 'Chinese (Traditional)',
          'ru' => 'Russian', 'ar' => 'Arabic', 'nl' => 'Dutch',
          'pl' => 'Polish', 'cs' => 'Czech', 'sv' => 'Swedish',
          'da' => 'Danish', 'fi' => 'Finnish', 'no' => 'Norwegian'
        }.freeze

        LANG_PATTERN = /(?:translated_)?([a-z]{2}(?:-[A-Z]{2})?)\./.freeze

        def execute
          validate_args!

          uploader = YouTubeTranslator::YoutubeUploader.new
          uploader.authenticate!

          result = uploader.upload_caption(video_id, language, load_content, upload_options)
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
          @language ||= @options[:target_lang] || detect_language
        end

        def detect_language
          return extract_lang_from_filename if File.exist?(file_or_lang)

          file_or_lang
        end

        def extract_lang_from_filename
          match = File.basename(file_or_lang).match(LANG_PATTERN)
          match ? match[1] : file_or_lang
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

        def upload_options
          { name: caption_name, draft: @options[:draft] }
        end

        def caption_name
          @options[:caption_name] || "#{language_name} (YouTube Translator)"
        end

        def language_name
          LANGUAGE_NAMES.fetch(language, language.upcase)
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
