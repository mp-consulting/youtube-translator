# frozen_string_literal: true

module YouTubeTranslator
  # Extracts video ID from various YouTube URL formats
  # Single Responsibility: Video ID extraction and validation
  class VideoIdExtractor
    VIDEO_ID_PATTERN = /^[a-zA-Z0-9_-]{11}$/
    URL_PATTERNS = [
      %r{youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})},
      %r{youtu\.be/([a-zA-Z0-9_-]{11})},
      %r{youtube\.com/embed/([a-zA-Z0-9_-]{11})}
    ].freeze

    def self.extract(input)
      new(input).extract
    end

    def initialize(input)
      @input = input.to_s.strip
    end

    def extract
      extract_from_url || extract_direct_id || raise_invalid_input
    end

    private

    def extract_from_url
      URL_PATTERNS.each do |pattern|
        match = @input.match(pattern)
        return match[1] if match
      end
      nil
    end

    def extract_direct_id
      @input if @input.match?(VIDEO_ID_PATTERN)
    end

    def raise_invalid_input
      raise VideoNotFoundError, "Invalid YouTube video ID or URL: #{@input}"
    end
  end
end
