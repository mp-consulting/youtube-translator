# frozen_string_literal: true

require 'json'
require 'fileutils'

module YouTubeTranslator
  # Manages translation dictionaries
  # Single Responsibility: Dictionary persistence and lookup
  class Dictionary
    TRANSLATIONS_DIR = File.join(YouTubeTranslator.root, 'translations')

    def initialize(source_lang, target_lang)
      @source_lang = source_lang
      @target_lang = target_lang
      @entries = load_entries
    end

    def lookup(word)
      @entries[word.downcase]
    end

    def add(source_word, translated_word)
      @entries[source_word.downcase] = translated_word
      save_entries
    end

    def remove(word)
      @entries.delete(word.downcase)
      save_entries
    end

    def all
      @entries.dup
    end

    def import(file_path)
      raise Error, "File not found: #{file_path}" unless File.exist?(file_path)

      imported = JSON.parse(File.read(file_path))
      imported.each { |source, target| @entries[source.downcase] = target }
      save_entries
      imported.size
    end

    def export(file_path)
      File.write(file_path, JSON.pretty_generate(@entries))
      @entries.size
    end

    def empty?
      @entries.empty?
    end

    def size
      @entries.size
    end

    private

    def file_path
      FileUtils.mkdir_p(TRANSLATIONS_DIR)
      File.join(TRANSLATIONS_DIR, "#{@source_lang}_to_#{@target_lang}.json")
    end

    def load_entries
      return {} unless File.exist?(file_path)

      JSON.parse(File.read(file_path))
    rescue JSON::ParserError
      {}
    end

    def save_entries
      File.write(file_path, JSON.pretty_generate(@entries))
    end
  end
end
