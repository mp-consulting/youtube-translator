# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'webrick'
require 'securerandom'

module YouTubeTranslator
  module OAuth
    # Handles Google OAuth 2.0 authentication flow
    # Single Responsibility: OAuth authentication
    class GoogleAuthenticator
      GOOGLE_AUTH_URL = 'https://accounts.google.com/o/oauth2/v2/auth'
      GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token'

      SCOPES = [
        'https://www.googleapis.com/auth/youtube.force-ssl'
      ].freeze

      def initialize(client_id:, client_secret:, token_store:, redirect_port: 8080)
        @client_id = client_id
        @client_secret = client_secret
        @token_store = token_store
        @redirect_port = redirect_port
      end

      def authenticate!
        return if authenticated?

        load_and_refresh_tokens || perform_oauth_flow
      end

      def authenticated?
        @token_store.valid?
      end

      def access_token
        @token_store.access_token
      end

      def clear_authentication
        @token_store.clear
      end

      private

      def load_and_refresh_tokens
        return false unless @token_store.load

        refresh_token_if_needed
      end

      def refresh_token_if_needed
        return true unless @token_store.expired?
        return false unless @token_store.refresh_token

        refresh_access_token
      end

      def refresh_access_token
        response = post_token_request(refresh_token_params)
        data = JSON.parse(response.body)

        return handle_refresh_failure if data['error']

        @token_store.update_access_token(
          access_token: data['access_token'],
          expires_at: Time.now + data['expires_in'].to_i
        )

        true
      end

      def handle_refresh_failure
        @token_store.clear
        false
      end

      def perform_oauth_flow
        state = SecureRandom.hex(16)
        auth_url = build_auth_url(state)

        display_auth_prompt(auth_url)
        open_browser(auth_url)

        code = wait_for_auth_callback(state)
        exchange_code_for_tokens(code)
      end

      def display_auth_prompt(auth_url)
        puts "\n=== YouTube Authorization Required ==="
        puts 'Opening browser for authorization...'
        puts "If browser doesn't open, visit this URL:\n\n"
        puts auth_url
        puts "\n"
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
        command = browser_open_command
        system(*command, url) if command
      end

      def browser_open_command
        case RUBY_PLATFORM
        when /darwin/ then ['open']
        when /linux/ then ['xdg-open']
        when /mswin|mingw/ then ['start']
        end
      end

      def wait_for_auth_callback(expected_state)
        server = create_callback_server
        code = nil

        server.mount_proc '/oauth/callback' do |req, res|
          code = handle_callback(req, res, expected_state)
          schedule_server_shutdown(server)
        end

        puts "Waiting for authorization (listening on port #{@redirect_port})..."
        server.start
        code
      end

      def create_callback_server
        WEBrick::HTTPServer.new(
          Port: @redirect_port,
          Logger: WEBrick::Log.new('/dev/null'),
          AccessLog: []
        )
      end

      def handle_callback(req, res, expected_state)
        error = req.query['error']
        state = req.query['state']

        if error
          res.body = error_response_html(error)
          raise Error, "OAuth authorization failed: #{error}"
        end

        if state != expected_state
          res.body = invalid_state_html
          raise Error, 'OAuth state mismatch - possible CSRF attack'
        end

        res.body = success_response_html
        req.query['code']
      end

      def error_response_html(error)
        "<html><body><h1>Authorization Failed</h1><p>#{error}</p></body></html>"
      end

      def invalid_state_html
        '<html><body><h1>Invalid State</h1></body></html>'
      end

      def success_response_html
        <<~HTML
          <html>
          <body>
            <h1>Authorization Successful!</h1>
            <p>You can close this window and return to the terminal.</p>
            <script>window.close();</script>
          </body>
          </html>
        HTML
      end

      def schedule_server_shutdown(server)
        Thread.new { sleep 1; server.shutdown }
      end

      def exchange_code_for_tokens(code)
        response = post_token_request(authorization_code_params(code))
        data = JSON.parse(response.body)

        raise_token_error(data) if data['error']

        @token_store.save(
          access_token: data['access_token'],
          refresh_token: data['refresh_token'],
          expires_at: Time.now + data['expires_in'].to_i
        )

        puts 'Successfully authenticated with YouTube!'
      end

      def raise_token_error(data)
        raise Error, "Token exchange failed: #{data['error_description'] || data['error']}"
      end

      def post_token_request(params)
        uri = URI(GOOGLE_TOKEN_URL)
        Net::HTTP.post_form(uri, params)
      end

      def authorization_code_params(code)
        {
          code: code,
          client_id: @client_id,
          client_secret: @client_secret,
          redirect_uri: redirect_uri,
          grant_type: 'authorization_code'
        }
      end

      def refresh_token_params
        {
          refresh_token: @token_store.refresh_token,
          client_id: @client_id,
          client_secret: @client_secret,
          grant_type: 'refresh_token'
        }
      end
    end
  end
end
