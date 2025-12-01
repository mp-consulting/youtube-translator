# frozen_string_literal: true

module YouTubeTranslator
  module CLI
    module Commands
      # Manages translation dictionary
      class Dictionary < Base
        SUBCOMMANDS = %w[add remove list import export].freeze

        def validate!
          raise Error, "Unknown dictionary command: #{subcommand}" unless valid_subcommand?
        end

        def run
          send("run_#{subcommand}")
        end

        private

        def subcommand
          @args.first
        end

        def subcommand_args
          @args.drop(1)
        end

        def valid_subcommand?
          SUBCOMMANDS.include?(subcommand)
        end

        def dictionary
          @dictionary ||= YouTubeTranslator::Dictionary.new(
            @options[:source_lang],
            @options[:target_lang]
          )
        end

        def run_add
          word, translation = subcommand_args
          raise Error, 'Usage: dict add <word> <translation>' unless word && translation

          dictionary.add(word, translation)
          log "Added: #{word} -> #{translation}"
        end

        def run_remove
          word = subcommand_args.first
          raise Error, 'Usage: dict remove <word>' unless word

          dictionary.remove(word)
          log "Removed: #{word}"
        end

        def run_list
          if dictionary.empty?
            log "No translations in dictionary for #{lang_pair}"
          else
            log "Translations (#{lang_pair}):"
            dictionary.all.each { |source, target| log "  #{source} -> #{target}" }
          end
        end

        def run_import
          file = subcommand_args.first
          raise Error, 'Usage: dict import <file>' unless file

          count = dictionary.import(file)
          log "Imported #{count} translations"
        end

        def run_export
          file = subcommand_args.first
          raise Error, 'Usage: dict export <file>' unless file

          count = dictionary.export(file)
          log "Exported #{count} translations to #{file}"
        end

        def lang_pair
          "#{@options[:source_lang]} -> #{@options[:target_lang]}"
        end
      end
    end
  end
end
