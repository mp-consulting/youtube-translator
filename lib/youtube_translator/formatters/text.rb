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
        hours = (seconds / 3600).to_i
        minutes = ((seconds % 3600) / 60).to_i
        secs = (seconds % 60).to_i

        if hours.positive?
          sprintf('%02d:%02d:%02d', hours, minutes, secs)
        else
          sprintf('%02d:%02d', minutes, secs)
        end
      end
    end
  end
end
