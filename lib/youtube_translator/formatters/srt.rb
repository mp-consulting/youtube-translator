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
        hours, minutes, secs, millis = decompose_time_with_millis(seconds)
        format('%02d:%02d:%02d,%03d', hours, minutes, secs, millis)
      end

      def decompose_time_with_millis(seconds)
        hours = (seconds / 3600).to_i
        minutes = ((seconds % 3600) / 60).to_i
        secs = (seconds % 60).to_i
        millis = ((seconds % 1) * 1000).to_i
        [hours, minutes, secs, millis]
      end
    end
  end
end
