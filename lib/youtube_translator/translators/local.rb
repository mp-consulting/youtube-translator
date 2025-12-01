# frozen_string_literal: true

module YouTubeTranslator
  module Translators
    # Dictionary-based local translator
    # Single Responsibility: Word-by-word translation using local dictionary
    class Local < Base
      WORD_PATTERN = /(\s+|[.,!?;:'"()\[\]{}])/
      PUNCTUATION_PATTERN = /^[.,!?;:'"()\[\]{}]+$/

      def initialize(source_lang, target_lang, dictionary: nil)
        super(source_lang, target_lang)
        @dictionary = dictionary || Dictionary.new(source_lang, target_lang)
      end

      def translate(text)
        return text if same_language?

        tokenize(text).map { |token| translate_token(token) }.join
      end

      protected

      def perform_translation(segments)
        segments.map do |segment|
          build_translated_segment(segment, translate(segment.text))
        end
      end

      private

      def tokenize(text)
        text.split(WORD_PATTERN)
      end

      def translate_token(token)
        return token if whitespace?(token) || punctuation?(token)

        translate_word(token)
      end

      def whitespace?(token)
        token.match?(/^\s+$/)
      end

      def punctuation?(token)
        token.match?(PUNCTUATION_PATTERN)
      end

      def translate_word(word)
        translation = @dictionary.lookup(word.downcase)
        return word unless translation

        preserve_case(word, translation)
      end

      def preserve_case(original, translated)
        if original == original.upcase
          translated.upcase
        elsif original == original.capitalize
          translated.capitalize
        else
          translated
        end
      end
    end
  end
end
