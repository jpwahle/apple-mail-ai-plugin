# Landing Page Design Spec

Single-page marketing site for AI Mail Composer, hosted on GitHub Pages.

## Tech Stack

- Single `docs/index.html` file with inline CSS and vanilla JS
- Zero dependencies — no build step, no CDN libraries
- GitHub Pages serves from `docs/` folder on `main` branch
- Logo and laurel SVG referenced from `docs/` assets

## Visual Direction

Light & clean. White/off-white background, generous whitespace, soft shadows. Apple product page feel. System font stack (`-apple-system, BlinkMacSystemFont, ...`).

## Page Structure

### 1. Laurel Badge

Full `laurel.svg` inlined, flanking the text "#1 Apple Mail AI Integration" with 5 gold stars beneath. Centered at the very top of the page above the hero. Small, understated — an award badge, not a banner.

### 2. Hero Section

- App icon (`logo.png`) at ~80px
- "AI Mail Composer" as the main heading
- Tagline: "Type your thoughts. AI writes the email."
- Two CTA buttons:
  - **"Download Latest" (primary, dark)** — links to the latest GitHub release. URL fetched dynamically from `https://api.github.com/repos/jpwahle/ai-apple-mail/releases/latest` on page load. Falls back to the releases page if the API call fails.
  - **"GitHub" (secondary, outlined)** — links to the repo
- Subtitle: "Open source · MIT License · macOS 14+"

### 3. Hero Animation (Main Mock)

A wide macOS-style window centered below the hero. The animation is the centerpiece of the page and must be polished. Full sequence (~8s loop):

**Step 1 — Window appears.** macOS window with traffic light dots and a title. Blinking cursor in an empty text area.

**Step 2 — Typing animation.** Characters appear one by one at variable speed (faster for easy chars, slight pauses at spaces/punctuation to feel human). The text: `"ya sounds good lets do thurs, also tell them we need the budget thing sorted"`. Shown in a muted, slightly messy style (gray, italic).

**Step 3 — Generate button.** Brief pause, then a "Generate" button in the mock gets a subtle press animation (scale down + shadow change). A shimmer/loading state plays for ~1 second.

**Step 4 — AI reply streams in.** The sloppy text fades out. The polished email streams in word-by-word (like actual LLM streaming output). Clean formatting, professional tone:

> Hi Sarah,
>
> Thursday works great for me. Looking forward to it.
>
> One more thing — could we get the budget finalized before then? That way we'll be ready to move forward at the meeting.
>
> Best,
> Jan

**Step 5 — Pause and reset.** Hold the final email for ~3 seconds, then fade out and loop back to step 1.

Animation quality requirements:
- Variable typing speed with human-like rhythm (not constant interval)
- Smooth easing on all transitions (no linear/abrupt changes)
- Streaming text should appear word-by-word with slight randomized delay between words
- The macOS window should have realistic styling: proper border-radius, subtle shadow, correct traffic light colors and spacing
- CSS keyframe animations preferred over JS intervals where possible for smoothness

### 4. Scroll Feature Sections

Three sections below the hero, each revealed with a fade-up animation on scroll (Intersection Observer, `threshold: 0.2`). Each section has:
- A short heading + one-line subtitle
- A macOS-style mock window illustrating the feature

**Section A — "Reads the whole thread"**
Subtitle: "The AI sees every message in the conversation — not just the last one"

Mock shows an email thread view with 3 messages (from Sarah, Mike, Sarah) each highlighted with a blue left border indicating the AI is reading them. A label "AI reads all of this ↑" separates the thread from the green-bordered generated reply at the bottom.

**Section B — "Pick your favorite model"**
Subtitle: "GPT, Claude, Gemini, or anything on OpenRouter"

Mock shows a model selector dropdown in its "open" state. Four rows:
- Claude Sonnet 4 (selected, with checkmark) — Anthropic orange badge
- GPT-4o — OpenAI green badge
- Gemini 2.5 Pro — Google blue badge
- OpenRouter · 100+ models — Indigo badge

**Section C — "Your key, your control"**
Subtitle: "No accounts. No subscriptions. Stored in macOS Keychain."

Mock shows a settings panel with three API key fields:
- Anthropic: masked key with "Valid" green badge
- OpenAI: masked key with "Valid" green badge
- Google Gemini: empty dashed-border field with placeholder
- A "Stored in macOS Keychain" lock badge at the bottom

### 5. Footer

Minimal. Centered text: "Open source · MIT License · Made for Apple Mail". Links to GitHub repo.

## Dynamic Release Link

On page load, fetch `https://api.github.com/repos/jpwahle/ai-apple-mail/releases/latest` and extract `assets[0].browser_download_url` for the DMG link. If the API call fails or there are no releases yet, the download button links to `https://github.com/jpwahle/ai-apple-mail/releases`.

## Scroll Animations

All feature sections use Intersection Observer to trigger once when 20% visible:
- Fade from `opacity: 0` to `1`
- Translate from `translateY(30px)` to `0`
- Duration: 600ms, ease-out
- Staggered: each section triggers independently as scrolled into view

## Responsive Behavior

- Max content width: ~900px centered
- Hero mock scales down on smaller screens (percentage-based width)
- On mobile (<640px): mock windows go full-width with smaller text
- Buttons stack vertically on mobile
- Laurel badge scales down but stays visible

## File Structure

```
docs/
  index.html      # The entire landing page
  logo.png        # App icon (copied from root)
  laurel.svg      # Laurel wreath (copied from root)
```

## Deployment

GitHub Pages configured to serve from `docs/` folder on `main` branch. No additional workflow needed — the existing release workflow pushes to `main`, which auto-deploys the page. Enable Pages in repo settings: Settings → Pages → Source: "Deploy from a branch", Branch: `main`, Folder: `/docs`.
