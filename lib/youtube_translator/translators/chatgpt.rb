# frozen_string_literal: true

module YouTubeTranslator
  module Translators
    # ChatGPT-based translator using OpenAI API
    # Single Responsibility: Translation via OpenAI API
    class ChatGPT < Base
      include LlmTranslator

      API_URL = 'https://api.openai.com/v1/chat/completions'

      def initialize(source_lang, target_lang, options = {})
        super(source_lang, target_lang)
        @api_key = options[:api_key] || YouTubeTranslator.configuration.openai_api_key
        @model = options[:model] || YouTubeTranslator.configuration.openai_model
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
              'OpenAI API key not found. Set OPENAI_API_KEY environment variable or use --api-key option'
      end

      def request_headers
        {
          'Content-Type' => 'application/json; charset=utf-8',
          'Authorization' => "Bearer #{@api_key}"
        }
      end

      def request_body(texts)
        body = {
          'model' => @model,
          'messages' => [
            { 'role' => 'system', 'content' => system_prompt },
            { 'role' => 'user', 'content' => user_prompt(texts) }
          ]
        }

        body['temperature'] = 0.3 unless reasoning_model?
        body
      end

      def reasoning_model?
        @model.include?('o1') || @model.include?('o3')
      end

      def handle_response(response, expected_count)
        unless response.success?
          error_msg = response.json.dig('error', 'message') rescue "HTTP #{response.code}"
          raise TranslationError, "OpenAI API error: #{error_msg}"
        end

        content = response.json.dig('choices', 0, 'message', 'content')
        raise TranslationError, 'Empty response from OpenAI' unless content

        parse_translations(content, expected_count)
      end
    end
  end
end
