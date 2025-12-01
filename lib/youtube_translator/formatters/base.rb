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
        extract_text(segment) || segment.to_s
      end

      def start_time(segment)
        segment_value(segment, :start)
      end

      def duration(segment)
        segment_value(segment, :duration)
      end

      def end_time(segment)
        start_time(segment) + duration(segment)
      end

      private

      def extract_text(segment)
        if segment.respond_to?(:translated_text) && segment.translated_text
          segment.translated_text
        elsif segment.respond_to?(:text)
          segment.text
        elsif segment.is_a?(Hash)
          segment[:translated_text] || segment[:text]
        end
      end

      def segment_value(segment, attr)
        segment.respond_to?(attr) ? segment.public_send(attr) : segment[attr]
      end
    end
  end
end
