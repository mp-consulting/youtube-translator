# frozen_string_literal: true

module YouTubeTranslator
  module Translators
    # Anthropic Claude-based translator
    # Single Responsibility: Translation via Anthropic API
    class Anthropic < Base
      ANTHROPIC_API_URL = 'https://api.anthropic.com/v1/messages'
      PROMPTS_DIR = File.join(YouTubeTranslator.root, 'lib', 'prompts')
      SYSTEM_PROMPT_FILE = File.join(PROMPTS_DIR, 'translation.md')
      DEFAULT_MODEL = 'claude-sonnet-4-20250514'

      def initialize(source_lang, target_lang, options = {})
        super(source_lang, target_lang)
        @api_key = options[:api_key] || YouTubeTranslator.configuration.anthropic_api_key
        @model = options[:model] || YouTubeTranslator.configuration.anthropic_model || DEFAULT_MODEL
        @http_client = options[:http_client] || HttpClient.new(read_timeout: 120)
        @dictionary = Dictionary.new(source_lang, target_lang)

        validate_api_key!
      end

      def translate(text)
        return text if same_language?

        translate_batch([text]).first || text
      end

      protected

      def perform_translation(segments)
        texts = segments.map(&:text)
        translations = translate_batch(texts)

        segments.each_with_index.map do |segment, idx|
          build_translated_segment(segment, translations[idx] || segment.text)
        end
      end

      private

      def validate_api_key!
        return if @api_key

        raise ConfigurationError,
              'Anthropic API key not found. Set ANTHROPIC_API_KEY environment variable or use --api-key option'
      end

      def translate_batch(texts)
        response = @http_client.post(
          ANTHROPIC_API_URL,
          request_body(texts),
          request_headers
        )

        translations = handle_response(response, texts.size)
        enforce_dictionary_terms(translations)
      end

      def enforce_dictionary_terms(translations)
        return translations if @dictionary.empty?

        translations.map { |text| apply_dictionary_terms(text) }
      end

      def apply_dictionary_terms(text)
        result = text
        @dictionary.all.each do |source_term, target_term|
          result = result.gsub(/\b#{Regexp.escape(source_term)}\b/i) do |match|
            preserve_case(match, target_term)
          end
        end
        result
      end

      def preserve_case(original, replacement)
        return replacement.upcase if original == original.upcase && original.length > 1
        return replacement.capitalize if original == original.capitalize

        replacement
      end

      def request_headers
        {
          'Content-Type' => 'application/json',
          'x-api-key' => @api_key,
          'anthropic-version' => '2023-06-01'
        }
      end

      def request_body(texts)
        {
          'model' => @model,
          'max_tokens' => 8192,
          'system' => system_prompt,
          'messages' => [
            { 'role' => 'user', 'content' => user_prompt(texts) }
          ]
        }
      end

      def system_prompt
        base_prompt = File.read(SYSTEM_PROMPT_FILE, encoding: 'UTF-8')
                          .gsub('{{SOURCE_LANG}}', language_name(@source_lang))
                          .gsub('{{TARGET_LANG}}', language_name(@target_lang))

        dictionary_context = build_dictionary_context
        dictionary_context.empty? ? base_prompt : "#{base_prompt}\n\n#{dictionary_context}"
      end

      def build_dictionary_context
        return '' if @dictionary.empty?

        terms = @dictionary.all.map { |source, target| "  - \"#{source}\" → \"#{target}\"" }
        "IMPORTANT: Use these specific translations for the following terms:\n#{terms.join("\n")}"
      end

      def user_prompt(texts)
        encoded = texts.map { |t| t.to_s.encode('UTF-8', invalid: :replace, undef: :replace) }
        lines = encoded.each_with_index.map { |t, i| "#{i + 1}. #{t}" }
        "Translate the following #{texts.size} text(s) to #{language_name(@target_lang)}:\n\n#{lines.join("\n")}"
      end

      def handle_response(response, expected_count)
        unless response.success?
          error_msg = response.json.dig('error', 'message') rescue "HTTP #{response.code}"
          raise TranslationError, "Anthropic API error: #{error_msg}"
        end

        parse_translations(response.json, expected_count)
      end

      def parse_translations(data, expected_count)
        content = data.dig('content', 0, 'text')
        raise TranslationError, 'Empty response from Anthropic' unless content

        parse_json_array(content) || parse_numbered_list(content, expected_count)
      end

      def parse_json_array(content)
        clean_content = content
                        .gsub(/```json\s*/i, '')
                        .gsub(/```\s*/, '')
                        .strip

        result = ::JSON.parse(clean_content)
        result if result.is_a?(Array)
      rescue ::JSON::ParserError
        nil
      end

      def parse_numbered_list(content, expected_count)
        lines = content.strip.split("\n")
        translations = lines.map { |l| l.sub(/^\d+\.\s*/, '').strip }.reject(&:empty?)

        return translations if translations.size == expected_count

        expected_count == 1 ? [content.strip] : Array.new(expected_count, content.strip)
      end

      def language_name(code)
        LANGUAGE_NAMES.fetch(code, code)
      end

      LANGUAGE_NAMES = {
        'en' => 'English', 'es' => 'Spanish', 'fr' => 'French', 'de' => 'German',
        'it' => 'Italian', 'pt' => 'Portuguese', 'ru' => 'Russian', 'ja' => 'Japanese',
        'ko' => 'Korean', 'zh' => 'Chinese', 'ar' => 'Arabic', 'hi' => 'Hindi',
        'nl' => 'Dutch', 'pl' => 'Polish', 'tr' => 'Turkish', 'vi' => 'Vietnamese',
        'th' => 'Thai', 'sv' => 'Swedish', 'da' => 'Danish', 'no' => 'Norwegian',
        'fi' => 'Finnish', 'cs' => 'Czech', 'el' => 'Greek', 'he' => 'Hebrew',
        'id' => 'Indonesian', 'ms' => 'Malay', 'ro' => 'Romanian', 'uk' => 'Ukrainian'
      }.freeze
    end
  end
end
