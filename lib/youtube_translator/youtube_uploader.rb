# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require 'securerandom'

module YouTubeTranslator
  # Uploads captions to YouTube using the YouTube Data API v3
  # Single Responsibility: YouTube caption API operations
  class YoutubeUploader
    YOUTUBE_CAPTIONS_URL = 'https://www.googleapis.com/youtube/v3/captions'
    YOUTUBE_UPLOAD_URL = 'https://www.googleapis.com/upload/youtube/v3/captions'

    def initialize(options = {})
      @config = YouTubeTranslator.configuration
      validate_credentials!(options)

      @authenticator = build_authenticator(options)
    end

    def upload_caption(video_id, language, content, options = {})
      ensure_authenticated!

      name = options[:name] || "#{language} (uploaded)"
      is_draft = options.fetch(:draft, false)

      existing = find_existing_caption(video_id, language)

      if existing
        update_caption(existing['id'], content, name: name, draft: is_draft)
      else
        insert_caption(video_id, language, content, name: name, draft: is_draft)
      end
    end

    def list_captions(video_id)
      ensure_authenticated!

      uri = build_captions_uri(video_id)
      response = authenticated_get(uri)
      handle_api_response(response)
    end

    def delete_caption(caption_id)
      ensure_authenticated!

      uri = URI(YOUTUBE_CAPTIONS_URL)
      uri.query = URI.encode_www_form(id: caption_id)

      response = authenticated_delete(uri)
      response.is_a?(Net::HTTPNoContent) || response.is_a?(Net::HTTPSuccess)
    end

    def authenticate!
      @authenticator.authenticate!
    end

    def authenticated?
      @authenticator.authenticated?
    end

    private

    def validate_credentials!(options)
      client_id = options[:client_id] || @config.google_client_id
      client_secret = options[:client_secret] || @config.google_client_secret

      return if client_id && client_secret

      raise ConfigurationError, credentials_error_message
    end

    def credentials_error_message
      <<~MSG
        Google OAuth credentials not configured.
        
        To upload captions to YouTube, you need to:
        1. Create a Google Cloud project at https://console.cloud.google.com
        2. Enable the YouTube Data API v3
        3. Create OAuth 2.0 credentials (Desktop application)
        4. Set environment variables:
           - GOOGLE_CLIENT_ID
           - GOOGLE_CLIENT_SECRET
        
        Or add them to your .env file.
      MSG
    end

    def build_authenticator(options)
      token_store = OAuth::TokenStore.new(@config.config_dir)

      OAuth::GoogleAuthenticator.new(
        client_id: options[:client_id] || @config.google_client_id,
        client_secret: options[:client_secret] || @config.google_client_secret,
        token_store: token_store,
        redirect_port: options[:redirect_port] || 8080
      )
    end

    def ensure_authenticated!
      authenticate! unless authenticated?
      raise Error, 'Failed to authenticate with YouTube' unless authenticated?
    end

    def build_captions_uri(video_id)
      uri = URI(YOUTUBE_CAPTIONS_URL)
      uri.query = URI.encode_www_form(part: 'snippet', videoId: video_id)
      uri
    end

    def find_existing_caption(video_id, language)
      result = list_captions(video_id)
      items = result['items'] || []
      items.find { |c| c.dig('snippet', 'language') == language }
    end

    def insert_caption(video_id, language, content, name:, draft:)
      metadata = build_insert_metadata(video_id, language, name, draft)
      upload_caption_content(nil, metadata, content)
    end

    def update_caption(caption_id, content, name:, draft:)
      metadata = build_update_metadata(caption_id, name, draft)
      upload_caption_content(caption_id, metadata, content)
    end

    def build_insert_metadata(video_id, language, name, draft)
      {
        snippet: {
          videoId: video_id,
          language: language,
          name: name,
          isDraft: draft
        }
      }
    end

    def build_update_metadata(caption_id, name, draft)
      metadata = { id: caption_id, snippet: { isDraft: draft } }
      metadata[:snippet][:name] = name if name
      metadata
    end

    def upload_caption_content(caption_id, metadata, content)
      uri = build_upload_uri(caption_id)
      boundary = generate_boundary
      body = build_multipart_body(boundary, metadata, content)

      response = execute_upload_request(uri, boundary, body)
      handle_api_response(response)
    end

    def build_upload_uri(caption_id)
      uri = URI(YOUTUBE_UPLOAD_URL)
      params = { part: 'snippet', uploadType: 'multipart' }
      params[:id] = caption_id if caption_id
      uri.query = URI.encode_www_form(params)
      uri
    end

    def generate_boundary
      "----YouTubeTranslator#{SecureRandom.hex(8)}"
    end

    def build_multipart_body(boundary, metadata, content)
      [
        "--#{boundary}",
        'Content-Type: application/json; charset=UTF-8',
        '',
        ::JSON.generate(metadata),
        "--#{boundary}",
        'Content-Type: text/plain; charset=UTF-8',
        '',
        content,
        "--#{boundary}--"
      ].join("\r\n")
    end

    def execute_upload_request(uri, boundary, body)
      http = build_https_client(uri)
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = authorization_header
      request['Content-Type'] = "multipart/related; boundary=#{boundary}"
      request.body = body
      http.request(request)
    end

    def authenticated_get(uri)
      execute_authenticated_request(Net::HTTP::Get, uri)
    end

    def authenticated_delete(uri)
      execute_authenticated_request(Net::HTTP::Delete, uri)
    end

    def execute_authenticated_request(request_class, uri)
      http = build_https_client(uri)
      request = request_class.new(uri)
      request['Authorization'] = authorization_header
      http.request(request)
    end

    def authorization_header
      "Bearer #{@authenticator.access_token}"
    end

    def build_https_client(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http
    end

    def handle_api_response(response)
      case response
      when Net::HTTPSuccess
        parse_success_response(response)
      when Net::HTTPUnauthorized
        handle_unauthorized_response
      when Net::HTTPForbidden
        handle_forbidden_response(response)
      else
        handle_error_response(response)
      end
    end

    def parse_success_response(response)
      response.body.empty? ? {} : JSON.parse(response.body)
    end

    def handle_unauthorized_response
      @authenticator.clear_authentication
      raise Error, 'YouTube API authentication expired. Please re-authenticate.'
    end

    def handle_forbidden_response(response)
      error = extract_error_message(response) || 'Access forbidden'
      raise Error, "YouTube API error: #{error}"
    end

    def handle_error_response(response)
      error = extract_error_message(response) || response.message
      raise Error, "YouTube API error (#{response.code}): #{error}"
    end

    def extract_error_message(response)
      data = JSON.parse(response.body)
      data.dig('error', 'message')
    rescue JSON::ParserError
      nil
    end
  end
end
