# frozen_string_literal: true

module YouTubeTranslator
  module Translators
    # Factory for creating translator instances
    # Factory Method pattern
    class Factory
      DEFAULT_MODELS = {
        'openai' => 'gpt-4o-mini',
        'anthropic' => 'claude-sonnet-4-5-20250929'
      }.freeze

      PROVIDERS = {
        'anthropic' => Anthropic,
        'openai' => ChatGPT
      }.freeze

      def self.build(source_lang, target_lang, options = {})
        new(source_lang, target_lang, options).build
      end

      def initialize(source_lang, target_lang, options = {})
        @source_lang = source_lang
        @target_lang = target_lang
        @options = options
      end

      def build
        klass = PROVIDERS[provider]
        return Local.new(@source_lang, @target_lang) unless klass

        klass.new(@source_lang, @target_lang, api_options)
      end

      private

      def provider
        @options[:provider] || YouTubeTranslator.configuration.llm_provider
      end

      def model
        # If model is explicitly provided, use it
        return @options[:model] if @options[:model]

        config = YouTubeTranslator.configuration

        # If provider matches config, use config model
        # Otherwise, use default model for the selected provider
        if provider == config.llm_provider
          config.llm_model
        else
          DEFAULT_MODELS[provider]
        end
      end

      def api_options
        {
          api_key: @options[:api_key],
          model: model
        }
      end
    end
  end
end
