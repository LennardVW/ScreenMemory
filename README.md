# ScreenMemory

📸 Searchable screenshot history with OCR. Never lose anything you've seen on screen.

## Features

- 📷 **Auto Capture** - Capture screenshots every 30 seconds
- 🔍 **OCR Search** - Search text inside screenshots
- 🧠 **Context Aware** - Knows which app/URL you were viewing
- 🏷️ **Auto Tagging** - AI-powered content categorization
- 📁 **Smart Organization** - Auto-sorted by date/app
- 🔗 **Deep Linking** - Jump back to source app/website
- 🗄️ **Efficient Storage** - Compresses and deduplicates
- 🔐 **Privacy First** - All processing local, no cloud

## Installation

```bash
git clone https://github.com/LennardVW/ScreenMemory.git
cd ScreenMemory
swift build -c release
cp .build/release/screenmemory /usr/local/bin/
```

## Usage

```bash
# Start background capture
screenmemory watch &

# Search for text
screenmemory search "error message"
screenmemory search "API key"

# List recent captures
screenmemory list 20

# Export screenshot
screenmemory export <id>

# View statistics
screenmemory stats
```

## Search Examples

```bash
# Find code snippets
screenmemory search "func main"

# Find error messages
screenmemory search "fatal error"

# Find by app
screenmemory search "from:xcode"

# Find by time
screenmemory search "2 hours ago"

# Find by URL
screenmemory search "url:github.com"
```

## Storage

Screenshots stored in: `~/Screenshots/YYYY/MM/DD/`

Database: `~/.screenmemory/db.sqlite`

## Privacy

- 100% local processing
- OCR runs on-device using Vision framework
- No internet connection required
- Optional encryption

## Requirements
- macOS 15.0+ (Tahoe)
- Swift 6.0+
- Screen Recording permission

## License
MIT
