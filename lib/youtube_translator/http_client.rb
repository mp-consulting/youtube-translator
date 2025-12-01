# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'openssl'

module YouTubeTranslator
  # HTTP client wrapper with consistent configuration
  # Single Responsibility: HTTP request handling
  class HttpClient
    DEFAULT_USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
    DEFAULT_OPEN_TIMEOUT = 10
    DEFAULT_READ_TIMEOUT = 30

    def initialize(options = {})
      @user_agent = options.fetch(:user_agent, DEFAULT_USER_AGENT)
      @open_timeout = options.fetch(:open_timeout, DEFAULT_OPEN_TIMEOUT)
      @read_timeout = options.fetch(:read_timeout, DEFAULT_READ_TIMEOUT)
      @verify_ssl = options.fetch(:verify_ssl, !ENV['SSL_VERIFY_NONE'])
    end

    def get(url, headers = {})
      uri = URI(url)
      request = build_request(Net::HTTP::Get, uri, headers)
      execute(uri, request)
    end

    def post(url, body, headers = {})
      uri = URI(url)
      request = build_request(Net::HTTP::Post, uri, headers)
      request.body = body.is_a?(Hash) ? body.to_json : body
      execute(uri, request)
    end

    private

    def build_request(method_class, uri, headers)
      request = method_class.new(uri)
      request['User-Agent'] = @user_agent
      headers.each { |key, value| request[key] = value }
      request
    end

    def execute(uri, request)
      http = create_http(uri)
      response = http.request(request)

      Response.new(response)
    end

    def create_http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout

      unless @verify_ssl
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      http
    end

    # Value Object for HTTP responses
    class Response
      attr_reader :code, :body

      def initialize(net_http_response)
        @code = net_http_response.code.to_i
        @body = net_http_response.body
        @success = net_http_response.is_a?(Net::HTTPSuccess)
      end

      def success?
        @success
      end

      def json
        @json ||= JSON.parse(@body)
      end
    end
  end
end
