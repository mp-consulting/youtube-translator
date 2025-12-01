# YouTube Translator

A Ruby CLI tool to fetch YouTube video transcripts and translate them using OpenAI or Anthropic LLMs.

## Features

- 🎬 **Fetch transcripts** from any YouTube video with captions
- 🌍 **Translate** using OpenAI (GPT-4o, GPT-4o-mini) or Anthropic (Claude)
- 📝 **Multiple formats**: Text, SRT, VTT, JSON
- 📖 **Custom dictionary** for consistent terminology
- 👀 **Review mode** to edit translations before finalizing
- 🔄 **Auto-generated captions** support with `--auto` flag

## Requirements

- Ruby 3.0+
- Bundler
- OpenAI or Anthropic API key

## Installation

```bash
# Clone the repository
git clone https://github.com/mp-consulting/youtube-translator.git
cd youtube-translator

# Install dependencies
bundle install

# Configure your API key
cp .env.example .env
# Edit .env with your API key
```

## Configuration

Create a `.env` file in the project root:

```bash
# LLM Provider: openai, anthropic, or local
LLM_PROVIDER=openai

# Model to use
LLM_MODEL=gpt-4o-mini

# API Keys
OPENAI_API_KEY=sk-your-openai-key
ANTHROPIC_API_KEY=sk-ant-your-anthropic-key

# Default languages
SOURCE_LANG=en
TARGET_LANG=fr
```

## Usage

### Fetch Transcript

```bash
# Fetch transcript (uses manual captions by default)
./bin/yt-translator fetch VIDEO_ID

# Fetch auto-generated transcript
./bin/yt-translator fetch VIDEO_ID --auto

# Fetch specific language
./bin/yt-translator fetch VIDEO_ID -s fr

# Save to file
./bin/yt-translator fetch VIDEO_ID -o transcript.txt

# Export as SRT subtitles
./bin/yt-translator fetch VIDEO_ID -f srt -o subtitles.srt
```

### List Available Languages

```bash
./bin/yt-translator languages VIDEO_ID
```

### Fetch All Transcripts

Download all available transcripts (all languages + auto-generated) to local files:

```bash
# Save all transcripts as text files
./bin/yt-translator fetch-all VIDEO_ID

# Save as SRT subtitles
./bin/yt-translator fetch-all VIDEO_ID -f srt

# Files are saved in transcripts/<video_id>/
#   - en.txt (manual English)
#   - en_auto.txt (auto-generated English)
#   - fr.txt, de.txt, etc.
```

### Translate

```bash
# Translate to French (uses LLM_PROVIDER from .env)
./bin/yt-translator translate VIDEO_ID -t fr

# Use OpenAI
./bin/yt-translator translate VIDEO_ID --openai -t fr

# Use Anthropic/Claude
./bin/yt-translator translate VIDEO_ID --anthropic -t fr

# Specify model
./bin/yt-translator translate VIDEO_ID --model gpt-4o -t es

# Export as SRT
./bin/yt-translator translate VIDEO_ID -t de -f srt -o german.srt

# Use auto-generated transcript as source
./bin/yt-translator translate VIDEO_ID --auto -t fr
```

### Review Mode

Review and edit translations before finalizing:

```bash
# Create review files
./bin/yt-translator review VIDEO_ID -t fr

# Files are saved in reviews/<provider>/
#   - VIDEO_ID_<provider>_original.txt
#   - VIDEO_ID_<provider>_translated_fr.txt
#   - VIDEO_ID_<provider>_review.txt (edit this)
#   - VIDEO_ID_<provider>_segments.json
```

### Dictionary

Maintain consistent translations for specific terms:

```bash
# Add term
./bin/yt-translator dict add "API" "API" -s en -t fr

# List terms
./bin/yt-translator dict list -s en -t fr

# Remove term
./bin/yt-translator dict remove "API" -s en -t fr

# Import/Export
./bin/yt-translator dict export terms.json -s en -t fr
./bin/yt-translator dict import terms.json -s en -t fr
```

Dictionary terms are automatically included in LLM prompts for consistent translations.

## Options

| Option | Description |
|--------|-------------|
| `-f, --format FORMAT` | Output format: `text`, `srt`, `vtt`, `json` |
| `-s, --source LANG` | Source language code |
| `-t, --target LANG` | Target language code |
| `-o, --output FILE` | Output to file |
| `--auto` | Prefer auto-generated transcripts |
| `--no-timestamps` | Exclude timestamps from text output |
| `--provider PROVIDER` | LLM provider: `openai`, `anthropic`, `local` |
| `--openai` | Use OpenAI (shortcut) |
| `--anthropic`, `--claude` | Use Anthropic (shortcut) |
| `--model MODEL` | LLM model to use |
| `--api-key KEY` | API key (overrides .env) |
| `--no-ssl-verify` | Disable SSL verification |
| `-h, --help` | Show help |
| `-v, --version` | Show version |

## Commands

| Command | Description |
|---------|-------------|
| `fetch <url>` | Fetch transcript |
| `fetch-all <url>` | Fetch all transcripts to local files |
| `translate <url>` | Fetch and translate |
| `review <url>` | Save for review |
| `translate-reviewed <id>` | Translate reviewed file |
| `languages <url>` | List available languages |
| `dict add <word> <trans>` | Add dictionary term |
| `dict remove <word>` | Remove dictionary term |
| `dict list` | List dictionary |
| `dict import <file>` | Import dictionary |
| `dict export <file>` | Export dictionary |

## Project Structure

```
youtube-translator/
├── bin/
│   └── yt-translator        # CLI executable
├── lib/
│   ├── youtube_translator.rb
│   ├── prompts/
│   │   └── translation.md   # LLM system prompt
│   └── youtube_translator/
│       ├── cli/             # CLI commands
│       ├── formatters/      # Output formatters
│       ├── translators/     # LLM integrations
│       ├── configuration.rb
│       ├── dictionary.rb
│       ├── transcript_fetcher.rb
│       └── ...
├── reviews/                 # Review files by provider
├── transcripts/             # Downloaded transcripts by video ID
├── translations/            # Dictionary files
├── .env.example
├── Gemfile
└── README.md
```

## Troubleshooting

### No captions available

The video doesn't have captions enabled. Try `--auto` for auto-generated captions.

### SSL errors

Behind a corporate proxy? Use `--no-ssl-verify`:

```bash
./bin/yt-translator fetch VIDEO_ID --no-ssl-verify
```

## License

MIT
