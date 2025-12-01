# frozen_string_literal: true

module YouTubeTranslator
  module Translators
    # Anthropic Claude-based translator
    # Single Responsibility: Translation via Anthropic API
    class Anthropic < Base
      include LlmTranslator

      API_URL = 'https://api.anthropic.com/v1/messages'
      DEFAULT_MODEL = 'claude-sonnet-4-20250514'

      def initialize(source_lang, target_lang, options = {})
        super(source_lang, target_lang)
        @api_key = options[:api_key] || YouTubeTranslator.configuration.anthropic_api_key
        @model = options[:model] || YouTubeTranslator.configuration.anthropic_model || DEFAULT_MODEL
        @http_client = options[:http_client] || HttpClient.new(read_timeout: 120)
        @dictionary = Dictionary.new(source_lang, target_lang)

        validate_api_key!
      end

      private

      def api_url
        API_URL
      end

      def validate_api_key!
        return if @api_key

        raise ConfigurationError,
              'Anthropic API key not found. Set ANTHROPIC_API_KEY environment variable or use --api-key option'
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

      def handle_response(response, expected_count)
        unless response.success?
          error_msg = response.json.dig('error', 'message') rescue "HTTP #{response.code}"
          raise TranslationError, "Anthropic API error: #{error_msg}"
        end

        content = response.json.dig('content', 0, 'text')
        raise TranslationError, 'Empty response from Anthropic' unless content

        parse_translations(content, expected_count)
      end
    end
  end
end
