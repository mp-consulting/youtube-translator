#!/usr/bin/env ruby
# frozen_string_literal: true

require 'zeitwerk'

# YouTube Transcript Fetcher and Translator
module YouTubeTranslator
  class Error < StandardError; end
  class VideoNotFoundError < Error; end
  class NoCaptionsError < Error; end
  class TranslationError < Error; end
  class ConfigurationError < Error; end

  class << self
    def loader
      @loader ||= begin
        loader = Zeitwerk::Loader.new
        loader.push_dir(File.expand_path('youtube_translator', __dir__), namespace: YouTubeTranslator)
        loader.inflector.inflect(
          'cli' => 'CLI',
          'chatgpt' => 'ChatGPT',
          'json' => 'JSON',
          'srt' => 'SRT',
          'vtt' => 'VTT'
        )
        loader
      end
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def root
      File.expand_path('..', __dir__)
    end
  end
end

YouTubeTranslator.loader.setup
