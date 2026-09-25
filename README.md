# Kaizen

Pick the right tools for your next build — before you write a line of code.

## What it does

Starting a new project usually means guessing your way through a stack: which framework, which backend, which services, and what it's all going to cost before you've shipped anything. Kaizen turns that guesswork into a short conversation.

Describe your app — by typing or by voice — and Kaizen recommends the tools best suited to build it, at the lowest realistic cost, with a clear breakdown of why each one made the list.

## Core feature: Tool & Cost Recommendation

1. **Describe your project.** Use the chat interface or voice input to explain what you're building — the kind of app, the core features, your constraints (budget, timeline, team size).
2. **Get a tailored tool shortlist.** Kaizen analyzes your description and surfaces the tools genuinely suited to your goals — not a generic "best of" list. Each suggestion comes with its strengths and weaknesses laid out plainly, so you understand the tradeoff, not just the name.
3. **Ask follow-up questions.** Not sure why a tool was recommended, or how it stacks up against an alternative for your specific use case? Ask directly inside the flow — Kaizen explains what makes each option particularly suited (or unsuited) to what you're trying to build.
4. **Select and estimate.** Choose the tools you want to move forward with, and get an upfront cost estimate for the project as a whole — built from real pricing on the selected tools, not a rough guess.
5. **Share and go.** Once your stack is locked in, share the project setup forward to start building.

The goal is simple: walk in with an idea, walk out with a tool stack and a number, in one sitting.

## Local Groq configuration

The chat uses Groq's OpenAI-compatible API. Keep the API key out of source
control and inject it at build time:

```powershell
$env:GROQ_API_KEY = "your-groq-api-key"
flutter run -d <device-id> `
  --dart-define=GROQ_API_KEY=$env:GROQ_API_KEY
```

The default model is `openai/gpt-oss-120b`, matching the current Groq example.
Override it when needed with:

```powershell
$env:GROQ_MODEL = "openai/gpt-oss-120b"
```

The key is embedded in a development mobile build, so this approach is for
local testing only. Production builds should call a backend that keeps the
Groq key server-side.

## Roadmap

Tool selection is the first step — what happens *after* you commit to a stack is next on the list.

---

## Android release signing

`flutter build apk --release` uses a production signing key when all four
signing values are supplied. Never commit a keystore or `android/key.properties`.

For local development, generate and securely back up a key:

```powershell
keytool -genkeypair -v -keystore "$env:USERPROFILE\kaizen-release.keystore" -alias kaizen -keyalg RSA -keysize 2048 -validity 10000
```

Create the ignored `android/key.properties` file:

```properties
storePassword=your-store-password
keyPassword=your-key-password
keyAlias=kaizen
storeFile=C:/Users/your-user/kaizen-release.keystore
```

CI can provide the same values without a file through `KAIZEN_STORE_PASSWORD`,
`KAIZEN_KEY_PASSWORD`, `KAIZEN_KEY_ALIAS`, and `KAIZEN_STORE_FILE` environment
variables. The ordinary debug build remains available on a fresh checkout and
does not require signing configuration:

```powershell
flutter run
flutter build apk --debug
```

The `release` build type fails clearly when production signing is not configured;
it never silently falls back to the debug key. For a local, non-distributable
release-mode inspection build only, explicitly opt in:

```powershell
$env:KAIZEN_ALLOW_DEBUG_RELEASE_SIGNING = "true"
flutter build apk --release
```

That APK is not suitable for distribution or updates to production installs.
Unset the opt-in and configure one of the production signing methods above before
publishing.

Verify a production artifact with Android SDK Build Tools:

```powershell
& "C:\Users\your-user\AppData\Local\Android\Sdk\build-tools\<version>\apksigner.bat" verify --print-certs .\build\app\outputs\flutter-apk\app-release.apk
```

*Kaizen — know your stack, know your cost, before you start.*
