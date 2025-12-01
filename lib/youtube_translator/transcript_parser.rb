# frozen_string_literal: true

require 'cgi'

module YouTubeTranslator
  # Parses YouTube transcript XML into structured segments
  # Single Responsibility: Transcript XML parsing
  class TranscriptParser
    Segment = Struct.new(:start, :duration, :text, keyword_init: true)

    def self.parse(xml)
      new(xml).parse
    end

    def initialize(xml)
      @xml = xml.to_s.force_encoding('UTF-8')
    end

    def parse
      @xml.scan(text_pattern).map do |match|
        build_segment(*match)
      end
    end

    private

    def text_pattern
      /<text start="([^"]+)" dur="([^"]+)"[^>]*>(.*?)<\/text>/m
    end

    def build_segment(start, duration, text)
      Segment.new(
        start: start.to_f,
        duration: duration.to_f,
        text: decode_text(text)
      )
    end

    def decode_text(text)
      clean_text = text.gsub(/<[^>]+>/, '').strip
      decode_html_entities(clean_text)
    end

    def decode_html_entities(text)
      CGI.unescapeHTML(text)
         .gsub('&#39;', "'")
         .gsub('&quot;', '"')
         .gsub('&amp;', '&')
         .gsub('&lt;', '<')
         .gsub('&gt;', '>')
         .gsub(/\n/, ' ')
         .strip
    end
  end
end
