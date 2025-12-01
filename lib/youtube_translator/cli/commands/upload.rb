# frozen_string_literal: true

module YouTubeTranslator
  module CLI
    module Commands
      # Uploads captions to YouTube
      class Upload < Base
        def execute
          validate_args!
          
          uploader = YouTubeTranslator::YoutubeUploader.new
          uploader.authenticate!

          content = load_content
          result = uploader.upload_caption(
            video_id,
            language,
            content,
            name: caption_name,
            draft: @options[:draft]
          )

          display_result(result)
        end

        private

        def validate_args!
          raise Error, 'Usage: upload <video_id> <file_or_language>' if @args.length < 2
        end

        def video_id
          VideoIdExtractor.extract(@args[0])
        end

        def file_or_lang
          @args[1]
        end

        def language
          @options[:target_lang] || detect_language
        end

        def detect_language
          # If second arg looks like a file, try to extract language from filename
          if File.exist?(file_or_lang)
            # e.g., translated_fr.txt -> fr
            if match = File.basename(file_or_lang).match(/(?:translated_)?([a-z]{2}(?:-[A-Z]{2})?)\./)
              return match[1]
            end
          end
          
          # Default to treating second arg as language code
          file_or_lang
        end

        def load_content
          if File.exist?(file_or_lang)
            File.read(file_or_lang, encoding: 'UTF-8')
          elsif File.exist?(review_file_path)
            File.read(review_file_path, encoding: 'UTF-8')
          else
            raise Error, "File not found: #{file_or_lang}"
          end
        end

        def review_file_path
          provider = @options[:provider] || YouTubeTranslator.configuration.llm_provider
          File.join('reviews', provider, video_id, "translated_#{language}.txt")
        end

        def caption_name
          @options[:caption_name] || "#{language_name} (YouTube Translator)"
        end

        def language_name
          # Map common language codes to names
          names = {
            'en' => 'English',
            'fr' => 'French',
            'es' => 'Spanish',
            'de' => 'German',
            'it' => 'Italian',
            'pt' => 'Portuguese',
            'pt-BR' => 'Portuguese (Brazil)',
            'ja' => 'Japanese',
            'ko' => 'Korean',
            'zh' => 'Chinese',
            'zh-Hans' => 'Chinese (Simplified)',
            'zh-Hant' => 'Chinese (Traditional)',
            'ru' => 'Russian',
            'ar' => 'Arabic',
            'nl' => 'Dutch',
            'pl' => 'Polish',
            'cs' => 'Czech',
            'sv' => 'Swedish',
            'da' => 'Danish',
            'fi' => 'Finnish',
            'no' => 'Norwegian'
          }
          names[language] || language.upcase
        end

        def display_result(result)
          if result && result['id']
            puts "✓ Caption uploaded successfully!"
            puts "  Caption ID: #{result['id']}"
            puts "  Language: #{result.dig('snippet', 'language')}"
            puts "  Name: #{result.dig('snippet', 'name')}"
            puts "  Draft: #{result.dig('snippet', 'isDraft')}"
          else
            puts "Caption uploaded."
          end
        end
      end
    end
  end
end
