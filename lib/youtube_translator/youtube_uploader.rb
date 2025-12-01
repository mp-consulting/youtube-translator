# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require 'webrick'
require 'securerandom'

module YouTubeTranslator
  # Uploads captions to YouTube using the YouTube Data API v3
  # Requires OAuth 2.0 authentication
  class YoutubeUploader
    GOOGLE_AUTH_URL = 'https://accounts.google.com/o/oauth2/v2/auth'
    GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token'
    YOUTUBE_CAPTIONS_URL = 'https://www.googleapis.com/youtube/v3/captions'
    YOUTUBE_UPLOAD_URL = 'https://www.googleapis.com/upload/youtube/v3/captions'

    SCOPES = [
      'https://www.googleapis.com/auth/youtube.force-ssl'
    ].freeze

    def initialize(options = {})
      @config = YouTubeTranslator.configuration
      @client_id = options[:client_id] || @config.google_client_id
      @client_secret = options[:client_secret] || @config.google_client_secret
      @redirect_port = options[:redirect_port] || 8080

      validate_credentials!
    end

    def upload_caption(video_id, language, content, options = {})
      ensure_authenticated!

      name = options[:name] || "#{language} (uploaded)"
      is_draft = options.fetch(:draft, false)

      # Check if caption already exists
      existing = find_existing_caption(video_id, language)

      if existing
        update_caption(existing['id'], content, name: name, draft: is_draft)
      else
        insert_caption(video_id, language, content, name: name, draft: is_draft)
      end
    end

    def list_captions(video_id)
      ensure_authenticated!

      uri = URI(YOUTUBE_CAPTIONS_URL)
      uri.query = URI.encode_www_form(
        part: 'snippet',
        videoId: video_id
      )

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
      return if authenticated?

      # Try to load saved tokens first
      if load_saved_tokens
        return if refresh_token_if_needed
      end

      # Start OAuth flow
      perform_oauth_flow
    end

    def authenticated?
      !@access_token.nil? && !token_expired?
    end

    private

    def validate_credentials!
      return if @client_id && @client_secret

      raise ConfigurationError, <<~MSG
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

    def ensure_authenticated!
      authenticate! unless authenticated?
      raise Error, 'Failed to authenticate with YouTube' unless authenticated?
    end

    def perform_oauth_flow
      state = SecureRandom.hex(16)
      auth_url = build_auth_url(state)

      puts "\n=== YouTube Authorization Required ==="
      puts "Opening browser for authorization..."
      puts "If browser doesn't open, visit this URL:\n\n"
      puts auth_url
      puts "\n"

      # Try to open browser
      open_browser(auth_url)

      # Start local server to receive callback
      code = wait_for_auth_callback(state)
      exchange_code_for_tokens(code)
    end

    def build_auth_url(state)
      params = {
        client_id: @client_id,
        redirect_uri: redirect_uri,
        response_type: 'code',
        scope: SCOPES.join(' '),
        access_type: 'offline',
        prompt: 'consent',
        state: state
      }

      "#{GOOGLE_AUTH_URL}?#{URI.encode_www_form(params)}"
    end

    def redirect_uri
      "http://localhost:#{@redirect_port}/oauth/callback"
    end

    def open_browser(url)
      case RUBY_PLATFORM
      when /darwin/
        system('open', url)
      when /linux/
        system('xdg-open', url)
      when /mswin|mingw/
        system('start', url)
      end
    end

    def wait_for_auth_callback(expected_state)
      code = nil
      server = WEBrick::HTTPServer.new(
        Port: @redirect_port,
        Logger: WEBrick::Log.new('/dev/null'),
        AccessLog: []
      )

      server.mount_proc '/oauth/callback' do |req, res|
        state = req.query['state']
        error = req.query['error']

        if error
          res.body = "<html><body><h1>Authorization Failed</h1><p>#{error}</p></body></html>"
          raise Error, "OAuth authorization failed: #{error}"
        elsif state != expected_state
          res.body = '<html><body><h1>Invalid State</h1></body></html>'
          raise Error, 'OAuth state mismatch - possible CSRF attack'
        else
          code = req.query['code']
          res.body = <<~HTML
            <html>
            <body>
              <h1>Authorization Successful!</h1>
              <p>You can close this window and return to the terminal.</p>
              <script>window.close();</script>
            </body>
            </html>
          HTML
        end

        Thread.new { sleep 1; server.shutdown }
      end

      puts "Waiting for authorization (listening on port #{@redirect_port})..."
      server.start
      code
    end

    def exchange_code_for_tokens(code)
      uri = URI(GOOGLE_TOKEN_URL)
      response = Net::HTTP.post_form(uri, {
        code: code,
        client_id: @client_id,
        client_secret: @client_secret,
        redirect_uri: redirect_uri,
        grant_type: 'authorization_code'
      })

      data = JSON.parse(response.body)

      if data['error']
        raise Error, "Token exchange failed: #{data['error_description'] || data['error']}"
      end

      @access_token = data['access_token']
      @refresh_token = data['refresh_token']
      @token_expires_at = Time.now + data['expires_in'].to_i

      save_tokens
      puts 'Successfully authenticated with YouTube!'
    end

    def refresh_token_if_needed
      return true unless token_expired?
      return false unless @refresh_token

      uri = URI(GOOGLE_TOKEN_URL)
      response = Net::HTTP.post_form(uri, {
        refresh_token: @refresh_token,
        client_id: @client_id,
        client_secret: @client_secret,
        grant_type: 'refresh_token'
      })

      data = JSON.parse(response.body)

      if data['error']
        @access_token = nil
        @refresh_token = nil
        return false
      end

      @access_token = data['access_token']
      @token_expires_at = Time.now + data['expires_in'].to_i
      save_tokens

      true
    end

    def token_expired?
      return true unless @token_expires_at

      Time.now >= @token_expires_at - 60 # 60 second buffer
    end

    def tokens_file
      File.join(@config.config_dir, 'youtube_tokens.json')
    end

    def save_tokens
      FileUtils.mkdir_p(@config.config_dir)
      data = {
        access_token: @access_token,
        refresh_token: @refresh_token,
        expires_at: @token_expires_at&.to_i
      }
      File.write(tokens_file, JSON.pretty_generate(data))
      File.chmod(0600, tokens_file)
    end

    def load_saved_tokens
      return false unless File.exist?(tokens_file)

      data = JSON.parse(File.read(tokens_file))
      @access_token = data['access_token']
      @refresh_token = data['refresh_token']
      @token_expires_at = data['expires_at'] ? Time.at(data['expires_at']) : nil

      true
    rescue JSON::ParserError
      false
    end

    def find_existing_caption(video_id, language)
      result = list_captions(video_id)
      items = result['items'] || []

      items.find { |c| c.dig('snippet', 'language') == language }
    end

    def insert_caption(video_id, language, content, name:, draft:)
      metadata = {
        snippet: {
          videoId: video_id,
          language: language,
          name: name,
          isDraft: draft
        }
      }

      upload_caption_content(nil, metadata, content)
    end

    def update_caption(caption_id, content, name:, draft:)
      metadata = {
        id: caption_id,
        snippet: {
          isDraft: draft
        }
      }
      metadata[:snippet][:name] = name if name

      upload_caption_content(caption_id, metadata, content)
    end

    def upload_caption_content(caption_id, metadata, content)
      uri = URI(YOUTUBE_UPLOAD_URL)
      params = { part: 'snippet', uploadType: 'multipart' }
      params[:id] = caption_id if caption_id
      uri.query = URI.encode_www_form(params)

      boundary = "----YouTubeTranslator#{SecureRandom.hex(8)}"

      body = build_multipart_body(boundary, metadata, content)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{@access_token}"
      request['Content-Type'] = "multipart/related; boundary=#{boundary}"
      request.body = body

      response = http.request(request)
      handle_api_response(response)
    end

    def build_multipart_body(boundary, metadata, content)
      body = []
      body << "--#{boundary}"
      body << 'Content-Type: application/json; charset=UTF-8'
      body << ''
      body << JSON.generate(metadata)
      body << "--#{boundary}"
      body << 'Content-Type: text/plain; charset=UTF-8'
      body << ''
      body << content
      body << "--#{boundary}--"
      body.join("\r\n")
    end

    def authenticated_get(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{@access_token}"

      http.request(request)
    end

    def authenticated_delete(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Delete.new(uri)
      request['Authorization'] = "Bearer #{@access_token}"

      http.request(request)
    end

    def handle_api_response(response)
      case response
      when Net::HTTPSuccess
        response.body.empty? ? {} : JSON.parse(response.body)
      when Net::HTTPUnauthorized
        @access_token = nil
        raise Error, 'YouTube API authentication expired. Please re-authenticate.'
      when Net::HTTPForbidden
        data = JSON.parse(response.body) rescue {}
        error = data.dig('error', 'message') || 'Access forbidden'
        raise Error, "YouTube API error: #{error}"
      else
        data = JSON.parse(response.body) rescue {}
        error = data.dig('error', 'message') || response.message
        raise Error, "YouTube API error (#{response.code}): #{error}"
      end
    end
  end
end
