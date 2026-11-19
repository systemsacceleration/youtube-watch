# YouTube Watch for Claude

Give Claude any YouTube link and it pulls the video's full, timestamped transcript, then saves it or turns it into whatever you need: a summary, key points, show notes, social posts, or a Google Doc.

No API keys. No Python. Nothing else to install. (For the rare video without captions, there's an optional free fallback; see below.)

## What you need

- The **Claude desktop app**, using the **Code** tab (it has a built-in browser Claude can use).
- Optional: the **Google Drive** connector, if you want transcripts saved as a Google Doc. Add it once in Claude's settings under Connectors.

## Install

**Easiest:** paste this into Claude in the Code tab:

```text
Install the youtube-watch skill from https://github.com/systemsacceleration/youtube-watch
```

**Or** enter these in Claude Code, one at a time:

```text
/plugin marketplace add systemsacceleration/youtube-watch
/plugin install youtube-watch@youtube-watch
```

Then start a new session.

## Try it

```text
Get the transcript of this YouTube video and give me a 5-bullet summary with timestamps:
https://www.youtube.com/watch?v=...
```

```text
Pull the transcripts of these videos and put them all in one Google Doc:
<links>
```

## Good to know

- Claude reads what's **said** in the video (YouTube's captions). It doesn't see what's on screen.
- Most videos have captions, because YouTube creates them automatically. If one doesn't, Claude tells you and offers a free fallback: Google's Gemini listens to the video and transcribes it. That needs a free key from [Google AI Studio](https://aistudio.google.com/apikey), set up once, and Claude walks you through it. It only works on public videos, and on Gemini's free tier Google may use what's sent to improve its products. Gemini transcripts are written by AI, so check them before relying on them.
- Auto-generated captions have small mistakes. Proofread before quoting word for word.

## License

MIT
