# frozen_string_literal: true

require 'fileutils'
require 'json'

module YouTubeTranslator
  # Manages application configuration with support for .env files
  # Single Responsibility: Configuration loading and access
  class Configuration
    CONFIG_DIR = File.join(Dir.home, '.youtube_translator')
    CONFIG_FILE = File.join(CONFIG_DIR, 'config.json')

    DEFAULTS = {
      source_lang: 'en',
      target_lang: 'fr',
      llm_provider: 'openai',
      llm_model: 'gpt-4o-mini',
      innertube_api_key: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8'
    }.freeze

    attr_accessor :source_lang, :target_lang, :llm_provider, :llm_model,
                  :openai_api_key, :anthropic_api_key, :innertube_api_key

    def initialize
      load_dotenv
      apply_defaults
      load_config_file
      apply_environment
    end

    def save_openai_api_key(key)
      FileUtils.mkdir_p(CONFIG_DIR)
      config = load_json_config
      config['openai_api_key'] = key
      File.write(CONFIG_FILE, JSON.pretty_generate(config))
    end

    private

    def apply_defaults
      DEFAULTS.each { |key, value| send("#{key}=", value) }
    end

    def load_config_file
      config = load_json_config
      @openai_api_key = config['openai_api_key']
      @anthropic_api_key = config['anthropic_api_key']
    end

    def apply_environment
      @source_lang = ENV.fetch('SOURCE_LANG', @source_lang)
      @target_lang = ENV.fetch('TARGET_LANG', @target_lang)
      @llm_provider = ENV.fetch('LLM_PROVIDER', @llm_provider)
      @llm_model = ENV.fetch('LLM_MODEL', @llm_model)
      @openai_api_key = ENV.fetch('OPENAI_API_KEY', @openai_api_key)
      @anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', @anthropic_api_key)
      @innertube_api_key = ENV.fetch('INNERTUBE_API_KEY', @innertube_api_key)
    end

    def load_json_config
      return {} unless File.exist?(CONFIG_FILE)

      JSON.parse(File.read(CONFIG_FILE))
    rescue JSON::ParserError
      {}
    end

    def load_dotenv
      env_file = File.join(Dir.pwd, '.env')
      return unless File.exist?(env_file)

      File.readlines(env_file).each do |line|
        parse_env_line(line.strip)
      end
    end

    def parse_env_line(line)
      return if line.empty? || line.start_with?('#')

      match = line.match(/\A([A-Za-z_][A-Za-z0-9_]*)=(.*)\z/)
      return unless match

      key, value = match.captures
      ENV[key] ||= strip_quotes(value.strip)
    end

    def strip_quotes(value)
      if (value.start_with?('"') && value.end_with?('"')) ||
         (value.start_with?("'") && value.end_with?("'"))
        value[1..-2]
      else
        value
      end
    end
  end
end
