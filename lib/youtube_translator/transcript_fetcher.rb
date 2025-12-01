# frozen_string_literal: true

module YouTubeTranslator
  # Fetches transcripts from YouTube using the Innertube API
  # Single Responsibility: YouTube API interaction
  class TranscriptFetcher
    INNERTUBE_API_URL = 'https://www.youtube.com/youtubei/v1/player'

    Language = Struct.new(:code, :name, :auto_generated, keyword_init: true)

    def initialize(video_input, options = {})
      @video_id = VideoIdExtractor.extract(video_input)
      verify_ssl = options.fetch(:verify_ssl, true)
      @http_client = options[:http_client] || HttpClient.new(verify_ssl: verify_ssl)
      @api_key = YouTubeTranslator.configuration.innertube_api_key
    end

    def fetch(lang_code = nil)
      captions = fetch_caption_tracks
      raise NoCaptionsError, 'No captions available for this video' if captions.empty?

      url = find_transcript_url(captions, lang_code)
      raise NoCaptionsError, 'No transcript URL found' unless url

      fetch_transcript(url)
    end

    def available_languages
      fetch_caption_tracks.map do |track|
        Language.new(
          code: track['languageCode'],
          name: track.dig('name', 'simpleText') || track['languageCode'],
          auto_generated: track['kind'] == 'asr'
        )
      end
    end

    private

    def fetch_caption_tracks
      response = @http_client.post(
        "#{INNERTUBE_API_URL}?key=#{@api_key}",
        innertube_request_body,
        { 'Content-Type' => 'application/json' }
      )

      raise Error, "Failed to fetch video data: HTTP #{response.code}" unless response.success?

      response.json.dig('captions', 'playerCaptionsTracklistRenderer', 'captionTracks') || []
    end

    def innertube_request_body
      {
        'context' => {
          'client' => {
            'clientName' => 'WEB',
            'clientVersion' => '2.20231121.08.00',
            'hl' => 'en'
          }
        },
        'videoId' => @video_id
      }
    end

    def find_transcript_url(captions, lang_code)
      track = if lang_code
                captions.find { |t| t['languageCode'] == lang_code }
              else
                captions.find { |t| t['kind'] != 'asr' } || captions.first
              end

      track&.dig('baseUrl')
    end

    def fetch_transcript(url)
      response = @http_client.get(url)
      raise Error, "Failed to fetch transcript: HTTP #{response.code}" unless response.success?

      TranscriptParser.parse(response.body)
    end
  end
end
