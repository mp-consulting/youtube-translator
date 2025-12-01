# frozen_string_literal: true

require 'fileutils'
require 'json'

module YouTubeTranslator
  # Manages application configuration with support for .env files
  # Single Responsibility: Configuration loading and access
  class Configuration
    # Directory paths relative to APP_ROOT
    REVIEWS_DIR = 'reviews'
    TRANSCRIPTS_DIR = 'transcripts'
    TRANSLATIONS_DIR = 'translations'
    CONFIG_SUBDIR = 'config'

    DEFAULTS = {
      source_lang: 'en',
      target_lang: 'fr',
      llm_provider: 'openai',
      llm_model: 'gpt-4o-mini',
      innertube_api_key: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8'
    }.freeze

    attr_accessor :source_lang, :target_lang, :llm_provider, :llm_model,
                  :openai_api_key, :anthropic_api_key, :innertube_api_key,
                  :google_client_id, :google_client_secret

    def initialize
      load_dotenv
      apply_defaults
      load_config_file
      apply_environment
    end

    def config_dir
      File.join(YouTubeTranslator::APP_ROOT, CONFIG_SUBDIR)
    end

    def config_file
      File.join(config_dir, 'config.json')
    end

    def reviews_dir
      File.join(YouTubeTranslator::APP_ROOT, REVIEWS_DIR)
    end

    def transcripts_dir
      File.join(YouTubeTranslator::APP_ROOT, TRANSCRIPTS_DIR)
    end

    def translations_dir
      File.join(YouTubeTranslator::APP_ROOT, TRANSLATIONS_DIR)
    end

    def save_openai_api_key(key)
      FileUtils.mkdir_p(config_dir)
      config = load_json_config
      config['openai_api_key'] = key
      File.write(config_file, JSON.pretty_generate(config))
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
      @google_client_id = ENV.fetch('GOOGLE_CLIENT_ID', @google_client_id)
      @google_client_secret = ENV.fetch('GOOGLE_CLIENT_SECRET', @google_client_secret)
    end

    def load_json_config
      return {} unless File.exist?(config_file)

      JSON.parse(File.read(config_file))
    rescue JSON::ParserError
      {}
    end

    def load_dotenv
      env_file = File.join(Dir.pwd, '.env')
      return unless File.exist?(env_file)

      File.readlines(env_file, chomp: true).each { |line| parse_env_line(line) }
    end

    def parse_env_line(line)
      return if line.empty? || line.start_with?('#')

      key, value = extract_env_pair(line)
      ENV[key] ||= strip_quotes(value) if key
    end

    def extract_env_pair(line)
      match = line.match(/\A([A-Za-z_][A-Za-z0-9_]*)=(.*)\z/)
      match&.captures&.tap { |_, v| v.strip! }
    end

    def strip_quotes(value)
      return value[1..-2] if quoted?(value)

      value
    end

    def quoted?(value)
      (value.start_with?('"') && value.end_with?('"')) ||
        (value.start_with?("'") && value.end_with?("'"))
    end
  end
end
