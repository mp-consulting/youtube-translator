# frozen_string_literal: true

module YouTubeTranslator
  module Translators
    # Factory for creating translator instances
    # Factory Method pattern
    class Factory
      def self.build(source_lang, target_lang, options = {})
        new(source_lang, target_lang, options).build
      end

      def initialize(source_lang, target_lang, options = {})
        @source_lang = source_lang
        @target_lang = target_lang
        @options = options
      end

      def build
        if use_chatgpt?
          ChatGPT.new(@source_lang, @target_lang, chatgpt_options)
        else
          Local.new(@source_lang, @target_lang)
        end
      end

      private

      def use_chatgpt?
        @options[:use_chatgpt]
      end

      def chatgpt_options
        {
          api_key: @options[:api_key],
          model: @options[:model]
        }
      end
    end
  end
end
