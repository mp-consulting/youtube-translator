# YouTube Translator CLI

A Ruby CLI tool for fetching YouTube video transcriptions and translating them using ChatGPT or local translation dictionaries.

## Features

- 📥 Fetch transcripts from any YouTube video with captions
- 🤖 **ChatGPT translation** using OpenAI API for high-quality translations
- 📖 Local translation dictionaries integrated with ChatGPT prompts
- 📝 Multiple output formats: text, SRT, VTT, JSON
- 👀 **Review mode** - review and edit translations locally before finalizing
- 💾 Manage translation dictionaries (add, remove, import, export)
- ⚙️ Configurable via `.env` file
- 🔄 Zeitwerk autoloading for clean modular architecture

## Requirements

- Ruby 3.0 or higher
- Bundler
- OpenAI API key (for ChatGPT translation)

## Installation

1. Clone or download this repository

2. Install dependencies:

```bash
bundle install
```

3. Set up your configuration:

```bash
cp .env.example .env
# Edit .env and add your OpenAI API key
```

## Configuration

Create a `.env` file in the project directory with your settings:

```bash
# LLM Provider (openai, anthropic, or local)
LLM_PROVIDER=openai

# LLM Model to use
# OpenAI models: gpt-4o-mini, gpt-4o, gpt-4-turbo
# Anthropic models: claude-sonnet-4-5-20250929, claude-sonnet-4-20250514
LLM_MODEL=gpt-4o-mini

# API Keys (set the one for your chosen provider)
OPENAI_API_KEY=sk-your-api-key-here
ANTHROPIC_API_KEY=sk-ant-your-api-key-here

# Default source language code
SOURCE_LANG=en

# Default target language code
TARGET_LANG=fr
```

Alternatively, save your API key to the config file:

```bash
./bin/yt-translator --save-api-key YOUR_API_KEY
```

## Usage

### Fetch Transcript

```bash
# Using video URL
./bin/yt-translator fetch "https://www.youtube.com/watch?v=VIDEO_ID"

# Using just the video ID
./bin/yt-translator fetch VIDEO_ID

# Fetch specific language
./bin/yt-translator fetch VIDEO_ID -s fr

# Output to file
./bin/yt-translator fetch VIDEO_ID -o transcript.txt

# Different output formats
./bin/yt-translator fetch VIDEO_ID -f srt -o subtitles.srt
./bin/yt-translator fetch VIDEO_ID -f vtt -o subtitles.vtt
./bin/yt-translator fetch VIDEO_ID -f json -o transcript.json
```

### List Available Languages

```bash
./bin/yt-translator languages VIDEO_ID
```

### Translate with LLM

```bash
# Translate to French using OpenAI (default provider)
./bin/yt-translator translate VIDEO_ID -t fr

# Explicitly use OpenAI
./bin/yt-translator translate VIDEO_ID --openai -t fr

# Use Anthropic/Claude
./bin/yt-translator translate VIDEO_ID --anthropic -t fr

# Use a specific model
./bin/yt-translator translate VIDEO_ID --provider openai --model gpt-4o -t es

# Output as SRT subtitles
./bin/yt-translator translate VIDEO_ID -t de -f srt -o german.srt
```

### Review Translations Locally

The review workflow lets you check and edit translations before finalizing:

```bash
# 1. Fetch, translate, and save for review
./bin/yt-translator review VIDEO_ID -t fr

# This creates files in the reviews/<provider>/ folder:
#   - VIDEO_ID_openai_original.txt      (original transcript)
#   - VIDEO_ID_openai_translated_fr.txt (translated transcript)
#   - VIDEO_ID_openai_review.txt        (side-by-side for editing)
#   - VIDEO_ID_openai_segments.json     (timing data)

# 2. Open and edit reviews/openai/VIDEO_ID_openai_review.txt
```

### Manage Translation Dictionary

The dictionary integrates with ChatGPT - your custom terms are included in the translation prompt to ensure consistent terminology.

```bash
# Add translations (English to French)
./bin/yt-translator dict add hello bonjour -s en -t fr
./bin/yt-translator dict add battery batterie -s en -t fr

# Remove a translation
./bin/yt-translator dict remove hello -s en -t fr

# List all translations
./bin/yt-translator dict list -s en -t fr

# Export translations to JSON
./bin/yt-translator dict export my_translations.json -s en -t fr

# Import translations from JSON
./bin/yt-translator dict import my_translations.json -s en -t fr
```

Dictionary files are stored in `translations/` folder as JSON files.

### Translation File Format

The import/export files use simple JSON format:

```json
{
  "hello": "bonjour",
  "battery": "batterie",
  "thank you": "merci"
}
```

## Options

| Option | Description |
|--------|-------------|
| `-f, --format FORMAT` | Output format: text, srt, vtt, json (default: text) |
| `-s, --source LANG` | Source language code (default: en) |
| `-t, --target LANG` | Target language code (default: fr) |
| `-o, --output FILE` | Output to file instead of stdout |
| `--no-timestamps` | Exclude timestamps from text output |
| `--provider PROVIDER` | LLM provider: openai, anthropic, local |
| `--openai` | Use OpenAI for translation (shortcut) |
| `--anthropic, --claude` | Use Anthropic/Claude for translation (shortcut) |
| `--api-key KEY` | API key (or set via .env) |
| `--model MODEL` | LLM model (default: gpt-4o-mini) |
| `--save-api-key KEY` | Save API key to config file |
| `--no-ssl-verify` | Disable SSL certificate verification |
| `-h, --help` | Show help message |
| `-v, --version` | Show version |

## Commands

| Command | Description |
|---------|-------------|
| `fetch <url>` | Fetch transcript from YouTube video |
| `translate <url>` | Fetch and translate transcript |
| `review <url>` | Fetch, translate, and save for local review |
| `languages <url>` | List available caption languages |
| `dict add <word> <translation>` | Add word to dictionary |
| `dict remove <word>` | Remove word from dictionary |
| `dict list` | List all dictionary translations |
| `dict import <file>` | Import translations from JSON |
| `dict export <file>` | Export translations to JSON |

## Project Structure

```
youtube-translator/
├── bin/
│   └── yt-translator          # CLI executable
├── lib/
│   ├── youtube_translator.rb  # Main module with Zeitwerk loader
│   ├── prompts/
│   │   └── translation.md     # ChatGPT system prompt
│   └── youtube_translator/
│       ├── cli/               # CLI components
│       │   ├── commands/      # Command handlers
│       │   ├── option_parser.rb
│       │   └── runner.rb
│       ├── formatters/        # Output formatters (Text, SRT, VTT, JSON)
│       ├── translators/       # Translation strategies (Local, ChatGPT)
│       ├── configuration.rb
│       ├── dictionary.rb
│       ├── http_client.rb
│       ├── transcript_fetcher.rb
│       ├── transcript_parser.rb
│       └── video_id_extractor.rb
├── translations/              # Dictionary files
├── .env.example
├── Gemfile
└── README.md
```

## How It Works

### LLM Translation

When translating, the tool:
1. Fetches transcript segments from YouTube via Innertube API
2. Loads your custom dictionary terms
3. Sends segments to OpenAI or Anthropic with dictionary terms in the system prompt
4. Parses and formats the translated response

Customize the translation prompt by editing `lib/prompts/translation.md`.

### Dictionary Integration

Your dictionary terms are automatically included in ChatGPT prompts:
```
IMPORTANT: Use these specific translations for the following terms:
  - "battery" → "batterie"
  - "hello" → "bonjour"
```

This ensures consistent terminology across translations.

## Examples

### Quick Start

```bash
# 1. Install dependencies
bundle install

# 2. Set up your API key
cp .env.example .env
# Edit .env and add: OPENAI_API_KEY=sk-your-key

# 3. Translate a video to French
./bin/yt-translator translate VIDEO_ID -t fr

# 4. Export as SRT subtitles
./bin/yt-translator translate VIDEO_ID -t fr -f srt -o french.srt
```

### Build a Custom Dictionary

```bash
# Add your preferred translations
./bin/yt-translator dict add "EcoFlow" "EcoFlow" -s cs -t en
./bin/yt-translator dict add "battery" "batterie" -s en -t fr

# These terms will be used consistently in LLM translations
./bin/yt-translator translate VIDEO_ID -t fr
```

## Troubleshooting

### "No captions available for this video"

The video either doesn't have captions or has them disabled for external access.

### SSL Certificate Errors

Use the `--no-ssl-verify` flag if you're behind a corporate proxy:

```bash
./bin/yt-translator fetch VIDEO_ID --no-ssl-verify
```

### Encoding issues

The tool uses UTF-8 encoding. Make sure your terminal supports UTF-8 for proper display of special characters.

## License

MIT License - feel free to use and modify as needed.
