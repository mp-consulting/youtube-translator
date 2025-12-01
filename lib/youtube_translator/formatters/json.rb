# frozen_string_literal: true

require 'json'

module YouTubeTranslator
  module Formatters
    # JSON format for structured output
    class JSON < Base
      def format
        ::JSON.pretty_generate(serialize_segments)
      end

      private

      def serialize_segments
        @segments.map { |seg| serialize_segment(seg) }
      end

      def serialize_segment(segment)
        if segment.is_a?(Hash)
          segment
        else
          {
            start: segment.start,
            duration: segment.duration,
            text: segment.text
          }
        end
      end
    end
  end
end
