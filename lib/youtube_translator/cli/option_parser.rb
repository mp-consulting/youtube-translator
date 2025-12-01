# frozen_string_literal: true

require 'optparse'

module YouTubeTranslator
  module CLI
    # Parses command line options
    # Single Responsibility: CLI argument parsing
    class OptionParser
      attr_reader :options, :remaining_args

      DEFAULT_OPTIONS = {
        format: :text,
        timestamps: true,
        use_chatgpt: false,
        api_key: nil,
        model: nil
      }.freeze

      def initialize(args)
        @args = args.dup
        @options = build_default_options
      end

      def parse
        parser.parse!(@args)
        @remaining_args = @args
        self
      rescue ::OptionParser::InvalidOption => e
        raise Error, e.message
      end

      def command
        @remaining_args.first
      end

      def command_args
        @remaining_args.drop(1)
      end

      def help
        parser.to_s
      end

      private

      def build_default_options
        config = YouTubeTranslator.configuration
        DEFAULT_OPTIONS.merge(
          source_lang: config.source_lang,
          target_lang: config.target_lang,
          model: config.openai_model,
          use_chatgpt: ENV['USE_CHATGPT'] == 'true'
        )
      end

      def parser
        @parser ||= ::OptionParser.new do |opts|
          configure_banner(opts)
          configure_format_options(opts)
          configure_language_options(opts)
          configure_output_options(opts)
          configure_chatgpt_options(opts)
          configure_general_options(opts)
        end
      end

      def configure_banner(opts)
        opts.banner = <<~BANNER
          YouTube Translator CLI v#{YouTubeTranslator::Version::STRING}

          Usage: #{$PROGRAM_NAME} [command] [options]

          Commands:
            fetch <video_url>       Fetch transcript from YouTube video
            translate <video_url>   Fetch and translate transcript
            review <video_url>      Fetch transcript and save for local review
            translate-reviewed <id> Translate a reviewed transcript
            languages <video_url>   List available languages for video
            dict <subcommand>       Manage translation dictionary

          Dictionary subcommands:
            dict add <word> <translation>  Add word to dictionary
            dict remove <word>             Remove word from dictionary
            dict list                      List all translations
            dict import <file>             Import translations from JSON
            dict export <file>             Export translations to JSON

          Options:
        BANNER
      end

      def configure_format_options(opts)
        formats = Formatters::Factory.available_formats
        opts.on('-f', '--format FORMAT', formats, "Output format (#{formats.join(', ')})") do |f|
          @options[:format] = f
        end

        opts.on('--no-timestamps', 'Exclude timestamps from text output') do
          @options[:timestamps] = false
        end
      end

      def configure_language_options(opts)
        opts.on('-s', '--source LANG', 'Source language code') do |l|
          @options[:source_lang] = l
        end

        opts.on('-t', '--target LANG', 'Target language code') do |l|
          @options[:target_lang] = l
        end
      end

      def configure_output_options(opts)
        opts.on('-o', '--output FILE', 'Output to file instead of stdout') do |f|
          @options[:output_file] = f
        end
      end

      def configure_chatgpt_options(opts)
        opts.on('--chatgpt', 'Use ChatGPT API for translation') do
          @options[:use_chatgpt] = true
        end

        opts.on('--api-key KEY', 'OpenAI API key') do |k|
          @options[:api_key] = k
        end

        opts.on('--model MODEL', 'OpenAI model to use') do |m|
          @options[:model] = m
        end

        opts.on('--save-api-key KEY', 'Save OpenAI API key to config') do |k|
          YouTubeTranslator.configuration.save_openai_api_key(k)
          puts 'API key saved to ~/.youtube_translator/config.json'
          exit
        end
      end

      def configure_general_options(opts)
        opts.on('--no-ssl-verify', 'Disable SSL certificate verification') do
          @options[:no_ssl_verify] = true
        end

        opts.on('-h', '--help', 'Show this help message') do
          puts opts
          exit
        end

        opts.on('-v', '--version', 'Show version') do
          puts "YouTube Translator v#{YouTubeTranslator::Version::STRING}"
          exit
        end
      end
    end
  end
end
