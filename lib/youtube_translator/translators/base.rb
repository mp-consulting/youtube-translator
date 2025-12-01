# frozen_string_literal: true

module YouTubeTranslator
  module Translators
    # Base class for translators - Template Method pattern
    # Defines the interface and common behavior for all translators
    class Base
      attr_reader :source_lang, :target_lang

      def initialize(source_lang, target_lang)
        @source_lang = source_lang
        @target_lang = target_lang
      end

      def translate(text)
        raise NotImplementedError, "#{self.class} must implement #translate"
      end

      def translate_segments(segments)
        return segments if same_language?

        perform_translation(segments)
      end

      protected

      def same_language?
        @source_lang == @target_lang
      end

      def perform_translation(segments)
        raise NotImplementedError, "#{self.class} must implement #perform_translation"
      end

      def build_translated_segment(segment, translated_text)
        {
          start: segment.start,
          duration: segment.duration,
          text: segment.text,
          original_text: segment.text,
          translated_text: translated_text
        }
      end
    end
  end
end
