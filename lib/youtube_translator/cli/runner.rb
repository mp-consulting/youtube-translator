# frozen_string_literal: true

module YouTubeTranslator
  module CLI
    # Main CLI runner - routes commands to handlers
    # Single Responsibility: Command routing
    class Runner
      COMMANDS = {
        'fetch' => Commands::Fetch,
        'fetch-all' => Commands::FetchAll,
        'translate' => Commands::Translate,
        'review' => Commands::Review,
        'translate-reviewed' => :translate_reviewed,
        'upload' => Commands::Upload,
        'languages' => Commands::Languages,
        'dict' => Commands::Dictionary
      }.freeze

      def initialize(args = ARGV)
        @parser = OptionParser.new(args)
      end

      def run
        @parser.parse
        return show_help_and_exit unless command

        execute_command
      rescue Error => e
        puts "Error: #{e.message}"
        exit 1
      end

      private

      def command
        @parser.command
      end

      def command_args
        @parser.command_args
      end

      def options
        @parser.options
      end

      def execute_command
        handler = COMMANDS[command]
        return unknown_command_error unless handler

        build_command(handler).execute
      end

      def unknown_command_error
        puts "Unknown command: #{command}. Use --help for usage information."
        exit 1
      end

      def build_command(handler)
        if handler == :translate_reviewed
          Commands::Review.for_translate_reviewed(command_args, options)
        else
          handler.new(command_args, options)
        end
      end

      def show_help_and_exit
        puts 'No command specified. Use --help for usage information.'
        exit 1
      end
    end
  end
end
