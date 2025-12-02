# frozen_string_literal: true

module YouTubeTranslator
  module Formatters
    # SRT subtitle format
    class SRT < Base
      def format
        @segments.each_with_index.map do |seg, idx|
          format_entry(seg, idx + 1)
        end.join("\n")
      end

      private

      def format_entry(segment, index)
        <<~SRT
          #{index}
          #{format_timestamp(start_time(segment))} --> #{format_timestamp(end_time(segment))}
          #{text_for(segment)}
        SRT
      end

      def format_timestamp(seconds)
        Time.at(seconds).utc.strftime('%H:%M:%S,%L')
      end
    end
  end
end
