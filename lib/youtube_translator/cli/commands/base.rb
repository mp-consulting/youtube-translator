# frozen_string_literal: true

module YouTubeTranslator
  module CLI
    module Commands
      # Base class for CLI commands - Template Method pattern
      class Base
        def initialize(args, options)
          @args = args
          @options = options
        end

        def execute
          validate!
          run
        end

        protected

        def validate!
          # Override in subclasses if needed
        end

        def run
          raise NotImplementedError, "#{self.class} must implement #run"
        end

        def video_url
          @args.first
        end

        def require_video_url!
          raise Error, 'Please provide a YouTube video URL or ID' unless video_url
        end

        def fetcher
          @fetcher ||= TranscriptFetcher.new(video_url, verify_ssl: !@options[:no_ssl_verify])
        end

        def translator
          @translator ||= Translators::Factory.build(
            @options[:source_lang],
            @options[:target_lang],
            provider: @options[:provider],
            api_key: @options[:api_key],
            model: @options[:model]
          )
        end

        def effective_provider
          @options[:provider] || YouTubeTranslator.configuration.llm_provider
        end

        def effective_model
          return @options[:model] if @options[:model]

          config = YouTubeTranslator.configuration
          if effective_provider == config.llm_provider
            config.llm_model
          else
            Translators::Factory::DEFAULT_MODELS[effective_provider]
          end
        end

        def format_output(segments)
          Formatters::Factory.format(
            segments,
            @options[:format],
            include_timestamps: @options[:timestamps]
          )
        end

        def write_output(content)
          if @options[:output_file]
            File.write(@options[:output_file], content)
            puts "Output written to: #{@options[:output_file]}"
          else
            puts content
          end
        end

        def log(message)
          puts message
        end
      end
    end
  end
end
