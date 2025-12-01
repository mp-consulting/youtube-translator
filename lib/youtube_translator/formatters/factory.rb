# frozen_string_literal: true

module YouTubeTranslator
  module Formatters
    # Factory for creating formatter instances
    # Factory Method pattern
    class Factory
      FORMATTERS = {
        text: 'Text',
        txt: 'Text',
        srt: 'SRT',
        vtt: 'VTT',
        json: 'JSON'
      }.freeze

      def self.build(format_type, segments, options = {})
        class_name = FORMATTERS[format_type.to_sym]
        raise Error, "Unknown format: #{format_type}" unless class_name

        Formatters.const_get(class_name).new(segments, options)
      end

      def self.format(segments, format_type, options = {})
        build(format_type, segments, options).format
      end

      def self.available_formats
        FORMATTERS.keys
      end
    end
  end
end
