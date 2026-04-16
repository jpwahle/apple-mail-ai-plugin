<p align="center">
  <img src="logo.png" width="128" height="128" alt="AI Mail Composer logo">
</p>

<h1 align="center">AI Mail Composer</h1>

<p align="center">
  A native macOS menu bar app that uses AI to help you write email replies in Apple Mail.
</p>

<p align="center">
  <a href="#installation">Installation</a> &middot;
  <a href="#get-your-api-key">Get Your API Key</a> &middot;
  <a href="#usage">Usage</a> &middot;
  <a href="#building-from-source">Build from Source</a>
</p>

---

AI Mail Composer lives in your menu bar and connects directly to Apple Mail. When you're composing a reply, press **Option + H** to open the composer panel. Type a few thoughts about what you want to say, pick an AI model, and the app writes your reply — matching the language and tone of the conversation.

**Bring your own API key.** No accounts, no subscriptions, no middleman. Your key is stored in macOS Keychain and calls go directly to the provider.

## Features

- **Menu bar app** — stays out of your way until you need it
- **Works with Apple Mail** — reads your email thread, recipients, subject, and current draft
- **Multiple AI providers** — Anthropic (Claude), OpenAI (GPT), Google Gemini, and OpenRouter
- **Streaming responses** — see the reply as it's being written
- **Language matching** — automatically replies in the same language as the conversation
- **Keyboard shortcut** — **⌥H** (Option + H) to open from anywhere
- **Secure key storage** — API keys stored in macOS Keychain, never on disk

## Installation

**Requirements:** macOS 14 (Sonoma) or later

### Download

Grab the latest `.dmg` from [Releases](../../releases), open it, and drag **AI Mail Composer** to your Applications folder.

> **macOS Gatekeeper:** Since the app isn't signed with an Apple Developer certificate, macOS will block it on first launch. To open it:
> 1. Right-click (or Control-click) the app and select **Open**
> 2. Click **Open** in the dialog that appears
>
> You only need to do this once. Alternatively, run:
> ```
> xattr -cr /Applications/AI\ Mail\ Composer.app
> ```

## Get Your API Key

AI Mail Composer calls AI providers directly — you'll need an API key from at least one provider. Pick whichever you prefer:

### Anthropic (Claude)

1. Go to [console.anthropic.com](https://console.anthropic.com/)
2. Sign up or log in
3. Navigate to **API Keys** in the sidebar
4. Click **Create Key**, give it a name, and copy the key

### OpenAI (GPT)

1. Go to [platform.openai.com](https://platform.openai.com/)
2. Sign up or log in
3. Navigate to **API Keys** in the sidebar
4. Click **Create new secret key**, name it, and copy the key

### Google Gemini

1. Go to [aistudio.google.com/apikey](https://aistudio.google.com/apikey)
2. Sign in with your Google account
3. Click **Create API Key**, select a project (or create one), and copy the key

### OpenRouter

1. Go to [openrouter.ai](https://openrouter.ai/)
2. Sign up or log in
3. Navigate to **Keys** in the sidebar
4. Click **Create Key**, name it, and copy the key

> **Tip:** OpenRouter gives you access to models from many providers through a single key. Great if you want to try different models without managing multiple accounts.

### Add Your Key to the App

1. Click the **AI Mail Composer** icon in your menu bar
2. Open **Settings**
3. Paste your API key for the provider you chose
4. The app will automatically fetch available models from that provider

## Usage

1. Open **Apple Mail** and start composing a reply
2. Press **⌥H** (Option + H) to open the composer panel
3. Type a few words describing what you want to say (e.g. "sounds good, let's meet thursday")
4. Pick a model from the dropdown
5. Hit **Generate** — the reply streams into your compose window

The app reads the full email thread for context, so the generated reply stays relevant to the conversation.

## Building from Source

```bash
git clone https://github.com/jpwahle/aimail.git
cd aimail
make build
make run
```

### Available Make Targets

| Command | Description |
|---------|-------------|
| `make build` | Debug build |
| `make run` | Build and launch the app |
| `make release` | Optimized release build |
| `make sign` | Code sign (ad-hoc or with `SIGNING_IDENTITY`) |
| `make dmg` | Create a `.dmg` installer |
| `make install` | Install to `/Applications` |
| `make clean` | Remove build artifacts |

### Notarization (for distribution)

```bash
make notarize \
  SIGNING_IDENTITY="Developer ID Application: ..." \
  APPLE_ID=you@example.com \
  TEAM_ID=ABC123
```

## Privacy

- API keys are stored in macOS Keychain — never written to disk as plain text
- Email content is sent directly to your chosen AI provider and nowhere else
- No analytics, no telemetry, no data collection

## License

[MIT](LICENSE)
