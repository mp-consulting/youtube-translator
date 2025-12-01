# frozen_string_literal: true

module YouTubeTranslator
  module Formatters
    # Base class for output formatters - Strategy pattern
    class Base
      def initialize(segments, options = {})
        @segments = segments
        @options = options
      end

      def format
        raise NotImplementedError, "#{self.class} must implement #format"
      end

      protected

      def text_for(segment)
        if segment.respond_to?(:translated_text) && segment.translated_text
          segment.translated_text
        elsif segment.respond_to?(:text)
          segment.text
        elsif segment.is_a?(Hash)
          segment[:translated_text] || segment[:text]
        else
          segment.to_s
        end
      end

      def start_time(segment)
        segment.respond_to?(:start) ? segment.start : segment[:start]
      end

      def duration(segment)
        segment.respond_to?(:duration) ? segment.duration : segment[:duration]
      end

      def end_time(segment)
        start_time(segment) + duration(segment)
      end
    end
  end
end
