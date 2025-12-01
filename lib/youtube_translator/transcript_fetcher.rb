# frozen_string_literal: true

require 'json'
require 'open3'
require 'shellwords'
require 'tempfile'

module YouTubeTranslator
  # Fetches transcripts from YouTube using the Innertube API or yt-dlp
  # Single Responsibility: YouTube API interaction
  class TranscriptFetcher
    INNERTUBE_API_URL = 'https://www.youtube.com/youtubei/v1/player'
    WATCH_URL = 'https://www.youtube.com/watch'

    Language = Struct.new(:code, :name, :auto_generated, keyword_init: true)

    def initialize(video_input, options = {})
      @video_id = VideoIdExtractor.extract(video_input)
      verify_ssl = options.fetch(:verify_ssl, true)
      @http_client = options[:http_client] || HttpClient.new(verify_ssl: verify_ssl)
      @api_key = YouTubeTranslator.configuration.innertube_api_key
      @use_ytdlp = false
    end

    def fetch(lang_code = nil, prefer_auto: false)
      captions = fetch_caption_tracks
      raise NoCaptionsError, 'No captions available for this video' if captions.empty?

      # If we're using yt-dlp mode, fetch via yt-dlp
      if @use_ytdlp
        return fetch_transcript_via_ytdlp(lang_code, prefer_auto: prefer_auto)
      end

      url = find_transcript_url(captions, lang_code, prefer_auto: prefer_auto)
      raise NoCaptionsError, 'No transcript URL found' unless url

      segments = fetch_transcript(url)

      # If segments are empty, try yt-dlp as fallback
      if segments.empty? && ytdlp_available?
        @use_ytdlp = true
        return fetch_transcript_via_ytdlp(lang_code, prefer_auto: prefer_auto)
      end

      segments
    end

    def available_languages
      fetch_caption_tracks.map do |track|
        name = track.dig('name', 'simpleText') || track.dig('name', 'runs', 0, 'text') || track['languageCode']
        # YouTube sometimes includes "(auto-generated)" in the name, strip it
        name = name.sub(/\s*\(auto-generated\)\s*/i, '').strip
        name = name.sub(/\s*\(gerada automaticamente\)\s*/i, '').strip
        Language.new(
          code: track['languageCode'],
          name: name,
          auto_generated: track['kind'] == 'asr'
        )
      end
    end

    private

    def fetch_caption_tracks
      # Try Innertube API first
      tracks = fetch_caption_tracks_via_api
      return tracks unless tracks.empty?

      # Try scraping watch page
      tracks = fetch_caption_tracks_via_watch_page
      return tracks unless tracks.empty?

      # Fallback to yt-dlp
      fetch_caption_tracks_via_ytdlp
    end

    def fetch_caption_tracks_via_api
      response = @http_client.post(
        "#{INNERTUBE_API_URL}?key=#{@api_key}",
        innertube_request_body,
        { 'Content-Type' => 'application/json' }
      )

      return [] unless response.success?

      response.json.dig('captions', 'playerCaptionsTracklistRenderer', 'captionTracks') || []
    end

    def fetch_caption_tracks_via_watch_page
      # Use curl as a fallback since Ruby's Net::HTTP gets different content from YouTube
      html = fetch_page_with_curl
      return [] if html.nil? || html.empty?

      parse_caption_tracks_from_html(html)
    end

    def fetch_page_with_curl
      url = "#{WATCH_URL}?v=#{@video_id}"
      cmd = [
        'curl', '-s', '--compressed',
        '-A', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        '-H', 'Accept-Language: en-US,en;q=0.9',
        url
      ]
      stdout, status = Open3.capture2(*cmd)
      status.success? ? stdout : nil
    rescue StandardError
      nil
    end

    def parse_caption_tracks_from_html(html)
      # Find captionTracks JSON in the page
      match = html.match(/"captionTracks":\s*(\[.*?\])(?=\s*[,}])/)
      return [] unless match

      # Unescape unicode
      json_str = match[1].gsub(/\\u([0-9a-fA-F]{4})/) { [$1.hex].pack('U') }
      JSON.parse(json_str)
    rescue JSON::ParserError
      []
    end

    def fetch_caption_tracks_via_ytdlp
      return [] unless ytdlp_available?

      @use_ytdlp = true
      json = fetch_ytdlp_info
      return [] unless json

      tracks = []

      # Manual subtitles
      if json['subtitles']
        json['subtitles'].each do |lang, formats|
          tracks << {
            'languageCode' => lang,
            'name' => { 'simpleText' => lang },
            'kind' => 'manual',
            '_ytdlp_formats' => formats
          }
        end
      end

      # Auto-generated captions
      if json['automatic_captions']
        json['automatic_captions'].each do |lang, formats|
          # Skip translated versions (they have "-" in the code like "en-orig")
          next if lang.include?('-') && !%w[zh-Hans zh-Hant pt-BR].include?(lang)

          tracks << {
            'languageCode' => lang,
            'name' => { 'simpleText' => lang },
            'kind' => 'asr',
            '_ytdlp_formats' => formats
          }
        end
      end

      tracks
    end

    def ytdlp_available?
      return @ytdlp_available if defined?(@ytdlp_available)

      _, status = Open3.capture2('which', 'yt-dlp')
      @ytdlp_available = status.success?
    end

    def fetch_ytdlp_info
      return @ytdlp_info if defined?(@ytdlp_info)

      cmd = [
        'yt-dlp',
        '--skip-download',
        '--write-subs',
        '--write-auto-subs',
        '--dump-json',
        '--no-warnings',
        "https://www.youtube.com/watch?v=#{@video_id}"
      ]

      stdout, status = Open3.capture2(*cmd)
      @ytdlp_info = status.success? && !stdout.empty? ? JSON.parse(stdout) : nil
    rescue JSON::ParserError
      @ytdlp_info = nil
    end

    def fetch_transcript_via_ytdlp(lang_code, prefer_auto: false)
      Dir.mktmpdir do |tmpdir|
        # Determine which subtitle to get
        sub_opts = if prefer_auto
                     ['--write-auto-subs', '--sub-langs', lang_code || 'en']
                   else
                     ['--write-subs', '--sub-langs', lang_code || 'en']
                   end

        cmd = [
          'yt-dlp',
          '--skip-download',
          *sub_opts,
          '--sub-format', 'json3',
          '--output', "#{tmpdir}/sub",
          "https://www.youtube.com/watch?v=#{@video_id}"
        ]

        Open3.capture2e(*cmd)

        # Find the subtitle file
        sub_file = Dir.glob("#{tmpdir}/*.json3").first

        unless sub_file
          # Try with auto-subs if manual didn't work
          cmd = [
            'yt-dlp',
            '--skip-download',
            '--write-auto-subs',
            '--sub-langs', lang_code || 'en',
            '--sub-format', 'json3',
            '--output', "#{tmpdir}/sub",
            "https://www.youtube.com/watch?v=#{@video_id}"
          ]
          Open3.capture2e(*cmd)
          sub_file = Dir.glob("#{tmpdir}/*.json3").first
        end

        return [] unless sub_file

        parse_json3_file(sub_file)
      end
    end

    def parse_json3_file(file_path)
      data = JSON.parse(File.read(file_path))
      events = data['events'] || []

      events.filter_map do |event|
        next unless event['segs']

        text = event['segs'].map { |seg| seg['utf8'] || '' }.join.strip
        next if text.empty?

        TranscriptParser::Segment.new(
          text: text,
          start: (event['tStartMs'] || 0) / 1000.0,
          duration: (event['dDurationMs'] || 0) / 1000.0
        )
      end
    end

    def innertube_request_body
      {
        'context' => {
          'client' => {
            'clientName' => 'WEB',
            'clientVersion' => '2.20241121.00.00',
            'hl' => 'en',
            'gl' => 'US'
          }
        },
        'videoId' => @video_id
      }
    end

    def find_transcript_url(captions, lang_code, prefer_auto: false)
      track = find_caption_track(captions, lang_code, prefer_auto)
      track&.dig('baseUrl')
    end

    def find_caption_track(captions, lang_code, prefer_auto)
      return find_by_language(captions, lang_code, prefer_auto) if lang_code

      find_by_preference(captions, prefer_auto)
    end

    def find_by_language(captions, lang_code, prefer_auto)
      preferred_kind = prefer_auto ? 'asr' : nil

      find_track_with_kind(captions, lang_code, preferred_kind) ||
        captions.find { |t| t['languageCode'] == lang_code }
    end

    def find_track_with_kind(captions, lang_code, kind)
      return nil unless kind

      captions.find { |t| t['languageCode'] == lang_code && t['kind'] == kind }
    end

    def find_by_preference(captions, prefer_auto)
      if prefer_auto
        captions.find { |t| t['kind'] == 'asr' } || captions.first
      else
        captions.find { |t| t['kind'] != 'asr' } || captions.first
      end
    end

    def fetch_transcript(url)
      response = @http_client.get(url)
      raise Error, "Failed to fetch transcript: HTTP #{response.code}" unless response.success?

      TranscriptParser.parse(response.body)
    end
  end
end
