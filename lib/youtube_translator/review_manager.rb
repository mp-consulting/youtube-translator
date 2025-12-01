# frozen_string_literal: true

require 'json'
require 'fileutils'

module YouTubeTranslator
  # Manages transcript review workflow
  # Single Responsibility: Review file creation and parsing
  class ReviewManager
    REVIEW_DIR = 'reviews'

    def initialize(video_id, options = {})
      @video_id = video_id
      @source_lang = options[:source_lang] || 'en'
      @target_lang = options[:target_lang] || 'fr'
      @provider = options[:provider] || YouTubeTranslator.configuration.llm_provider
      @include_timestamps = options.fetch(:include_timestamps, true)
    end

    def save_for_review(segments, translated_segments)
      ensure_review_dir

      save_original(segments)
      save_translated(translated_segments)
      save_segments_json(translated_segments)
      save_review_file(translated_segments)

      review_file_path
    end

    def load_reviewed_segments
      raise Error, review_not_found_message unless review_exists?

      segments = load_segments_json
      reviewed_texts = parse_review_file

      merge_reviewed_texts(segments, reviewed_texts)
    end

    def review_exists?
      File.exist?(review_file_path) && File.exist?(segments_json_path)
    end

    private

    def ensure_review_dir
      FileUtils.mkdir_p(review_dir)
    end

    def review_dir
      File.join(Dir.pwd, REVIEW_DIR, @provider, @video_id)
    end

    def original_file_path
      File.join(review_dir, 'original.txt')
    end

    def translated_file_path
      File.join(review_dir, "translated_#{@target_lang}.txt")
    end

    def segments_json_path
      File.join(review_dir, 'segments.json')
    end

    def review_file_path
      File.join(review_dir, 'review.txt')
    end

    def save_original(segments)
      output = Formatters::Factory.format(segments, :text, include_timestamps: @include_timestamps)
      File.write(original_file_path, output, encoding: 'UTF-8')
    end

    def save_translated(segments)
      output = Formatters::Factory.format(segments, :text, include_timestamps: @include_timestamps)
      File.write(translated_file_path, output, encoding: 'UTF-8')
    end

    def save_segments_json(segments)
      File.write(segments_json_path, JSON.pretty_generate(segments), encoding: 'UTF-8')
    end

    def save_review_file(segments)
      content = build_review_content(segments)
      File.write(review_file_path, content, encoding: 'UTF-8')
    end

    def build_review_content(segments)
      header = review_header
      body = segments.map { |seg| format_review_segment(seg) }.join("\n")
      header + body
    end

    def review_header
      <<~HEADER
        # YouTube Transcript Review
        # Video ID: #{@video_id}
        # Provider: #{@provider}
        # Source Language: #{@source_lang}
        # Target Language: #{@target_lang}
        #
        # Instructions:
        # 1. Review the translations below
        # 2. Edit the TRANSLATED lines as needed
        # 3. Save the file when done
        # ============================================

      HEADER
    end

    def format_review_segment(segment)
      timestamp = format_timestamp(segment[:start] || segment.start)
      original = segment[:original_text] || segment[:text] || segment.text
      translated = segment[:translated_text] || original

      "[#{timestamp}] ORIGINAL: #{original}\n[#{timestamp}] TRANSLATED: #{translated}\n"
    end

    def format_timestamp(seconds)
      minutes = (seconds / 60).to_i
      secs = (seconds % 60).to_i
      sprintf('%02d:%02d', minutes, secs)
    end

    def load_segments_json
      JSON.parse(File.read(segments_json_path, encoding: 'UTF-8'), symbolize_names: true)
    end

    def parse_review_file
      content = File.read(review_file_path, encoding: 'UTF-8')
      lines = content.lines.reject { |l| l.start_with?('#') || l.strip.empty? }

      lines.map { |l| l.sub(/^\[\d{2}:\d{2}(?::\d{2})?\]\s*/, '').strip }
           .reject(&:empty?)
    end

    def merge_reviewed_texts(segments, reviewed_texts)
      reviewed_texts.each_with_index do |text, idx|
        segments[idx][:text] = text if segments[idx]
      end
      segments
    end

    def review_not_found_message
      "Review file not found: #{review_file_path}\nRun 'review <video_url>' first."
    end
  end
end
