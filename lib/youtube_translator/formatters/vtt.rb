# frozen_string_literal: true

module YouTubeTranslator
  module Formatters
    # WebVTT subtitle format
    class VTT < Base
      HEADER = "WEBVTT\n\n"

      def format
        HEADER + @segments.map { |seg| format_cue(seg) }.join("\n")
      end

      private

      def format_cue(segment)
        <<~VTT
          #{format_timestamp(start_time(segment))} --> #{format_timestamp(end_time(segment))}
          #{text_for(segment)}
        VTT
      end

      def format_timestamp(seconds)
        Time.at(seconds).utc.strftime('%H:%M:%S.%L')
      end
    end
  end
end
