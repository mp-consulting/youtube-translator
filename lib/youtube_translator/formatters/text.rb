# frozen_string_literal: true

module YouTubeTranslator
  module Formatters
    # Plain text formatter with optional timestamps
    class Text < Base
      def format
        @segments.map { |seg| format_segment(seg) }.join("\n")
      end

      private

      def format_segment(segment)
        text = text_for(segment)
        return text unless include_timestamps?

        "[#{format_timestamp(start_time(segment))}] #{text}"
      end

      def include_timestamps?
        @options.fetch(:include_timestamps, true)
      end

      def format_timestamp(seconds)
        time = Time.at(seconds).utc
        time.hour.positive? ? time.strftime('%H:%M:%S') : time.strftime('%M:%S')
      end
    end
  end
end
