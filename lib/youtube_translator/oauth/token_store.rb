# frozen_string_literal: true

require 'json'
require 'fileutils'

module YouTubeTranslator
  module OAuth
    # Manages OAuth token persistence
    # Single Responsibility: Token storage and retrieval
    class TokenStore
      EXPIRY_BUFFER_SECONDS = 60

      attr_reader :access_token, :refresh_token, :expires_at

      def initialize(config_dir)
        @config_dir = config_dir
        @access_token = nil
        @refresh_token = nil
        @expires_at = nil
      end

      def tokens_file
        File.join(@config_dir, 'youtube_tokens.json')
      end

      def save(access_token:, refresh_token:, expires_at:)
        @access_token = access_token
        @refresh_token = refresh_token
        @expires_at = expires_at

        write_to_file
      end

      def update_access_token(access_token:, expires_at:)
        @access_token = access_token
        @expires_at = expires_at

        write_to_file
      end

      def load
        return false unless File.exist?(tokens_file)

        data = JSON.parse(File.read(tokens_file))
        @access_token = data['access_token']
        @refresh_token = data['refresh_token']
        @expires_at = data['expires_at'] ? Time.at(data['expires_at']) : nil

        true
      rescue JSON::ParserError
        false
      end

      def clear
        @access_token = nil
        @refresh_token = nil
        @expires_at = nil
      end

      def valid?
        !@access_token.nil? && !expired?
      end

      def expired?
        return true unless @expires_at

        Time.now >= @expires_at - EXPIRY_BUFFER_SECONDS
      end

      private

      def write_to_file
        FileUtils.mkdir_p(@config_dir)
        data = {
          access_token: @access_token,
          refresh_token: @refresh_token,
          expires_at: @expires_at&.to_i
        }
        File.write(tokens_file, JSON.pretty_generate(data))
        File.chmod(0o600, tokens_file)
      end
    end
  end
end
