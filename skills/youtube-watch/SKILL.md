---
name: youtube-watch
description: Get the full, timestamped transcript of one or more YouTube videos by opening them in Claude's browser, then save it or use it (summaries, notes, posts, a Google Doc). Use whenever the user shares a YouTube link and wants Claude to read, watch, transcribe, summarize, or pull ideas from the video. Works with no API keys or installs for videos with captions; for videos without captions it can fall back to Google Gemini (free key).
---

# YouTube Watch

Read a YouTube video by opening it in a browser and copying the transcript YouTube already has. Nothing to install: this uses the browser Claude already has. For the rare video without captions, it can fall back to Google's Gemini (section 3), which needs a free key once.

**What this does and doesn't do.** It reads what was *said* in the video, from YouTube's captions (usually auto-generated), or from Gemini's transcription when there are none. It does not see what's on screen. Say so if the user asks about visuals. Auto-generated captions have small speech-to-text mistakes; mention that before anyone quotes the text word for word.

## 1. Pick a browser

Use the first one that's available:

1. **Claude's built-in browser** (the Claude desktop app's Code tab): tools named like `mcp__Claude_Browser__*`. Open the video with `preview_start` (pass `url`) or `navigate`.
2. **Claude in Chrome**: tools named like `mcp__claude-in-chrome__*`.

If neither exists, tell the user plainly: this skill needs the Claude desktop app's **Code** tab (which has a built-in browser) or the Claude in Chrome extension. Don't try to install other software instead.

## 2. Get the transcript for each video

Work through the videos one at a time.

1. Navigate to the video URL.
2. Run the script below in the page with the browser's JavaScript tool. Set `vid` to the video's ID (the part after `v=`). It pauses the video, opens YouTube's transcript panel and reads it. If the panel doesn't load (it sometimes doesn't), it falls back to the caption file the video player already downloaded.

```js
const vid = 'VIDEO_ID_HERE';
const sleep = ms => new Promise(r => setTimeout(r, ms));
const fmt = ms => { const s = Math.floor(ms / 1000); return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`; };
let btn;
for (let i = 0; i < 16 && !btn; i++) {
  await sleep(500);
  document.querySelector('#description-inline-expander #expand, tp-yt-paper-button#expand')?.click();
  btn = [...document.querySelectorAll('button')].find(b => b.innerText.trim() === 'Show transcript');
}
let text = '', method = '';
if (btn) {
  btn.click();
  let segs = [];
  for (let i = 0; i < 20 && !segs.length; i++) {
    await sleep(500);
    segs = [...document.querySelectorAll('ytd-transcript-segment-renderer, transcript-segment-view-model')];
  }
  if (segs.length) {
    method = 'transcript panel';
    text = segs.map(s => { const l = s.innerText.split('\n').map(x => x.trim()).filter(Boolean); return `[${l[0]}] ${l.slice(2).join(' ')}`; }).join('\n');
  }
}
if (!text) {
  let u;
  for (let i = 0; i < 20 && !u; i++) {
    await sleep(500);
    u = performance.getEntriesByType('resource').map(e => e.name)
      .filter(n => n.includes('timedtext') && n.includes('v=' + vid) && n.includes('pot=')).pop();
  }
  if (u) {
    method = 'player captions';
    const j = await (await fetch(u)).json();
    const evs = (j.events || []).filter(e => e.segs)
      .map(e => ({ t: e.tStartMs, x: e.segs.map(s => s.utf8).join('') })).filter(e => e.x.trim());
    let out = [], cur = null;
    for (const e of evs) { if (!cur || e.t - cur.t >= 8000) { cur = { t: e.t, x: '' }; out.push(cur); } cur.x += ' ' + e.x.replace(/\n/g, ' '); }
    text = out.map(c => `[${fmt(c.t)}] ${c.x.replace(/\s+/g, ' ').trim()}`).join('\n');
  }
}
document.querySelector('video')?.pause();
const pr = document.querySelector('#movie_player')?.getPlayerResponse?.();
({ title: pr?.videoDetails?.title, lengthSeconds: pr?.videoDetails?.lengthSeconds,
   captionTracks: (pr?.captions?.playerCaptionsTracklistRenderer?.captionTracks || []).map(t => t.languageCode + '/' + (t.kind || 'manual')),
   method, text })
```

3. Check the result:
   - **`text` is filled**: done. The last timestamp should be close to the video's length.
   - **`text` is empty but `captionTracks` lists a track**: the page probably hadn't finished loading. Reload the video once and run the script again. If it's still empty, take a screenshot, look for the transcript yourself (it's under the description: expand "...more", then "Show transcript"), and adapt the script; YouTube changes its page from time to time.
   - **`captionTracks` is empty**: the video has no captions. Finish the videos that do have them, then use the Gemini fallback in section 3 for the ones that don't. Never invent or guess what a video says.

## 3. Fallback for videos without captions: Gemini

Google's Gemini model can listen to a public YouTube video and write out what's said. The free tier covers this. It needs a free API key once; after that it works automatically.

**Before using it, tell the user**, in plain words:

> "<video title>" has no captions on YouTube, so I can't read its transcript. I can have Google's Gemini listen to it and transcribe it instead. It's free, but it needs a free key from Google, which takes about a minute to get, once. Two things to know: it only works on public videos, and on Gemini's free tier Google may use what's sent to improve its products. Want to set that up?

If they say no, skip that video and say so in your final answer.

### Run it

Run the bundled script (`scripts/` sits next to this file):

```bash
bash "<this skill's folder>/scripts/gemini-transcript.sh" "<youtube-url>" "<output>.json"
```

- **Exit 0**: the response is saved as JSON. Read the file, find the transcript text the model returned, and save it the same way as in section 4. In the header, set Source to `Transcribed by Google Gemini from the video's audio (no YouTube captions)`, because this text was written by AI and can contain mistakes or invented words. If the model replied `NO SPEECH`, tell the user the video has no speech to transcribe.
- **Exit 3 (`NO_KEY`)**: there's no key yet. Walk the user through setup, below, then run the script again.
- **Exit 4 (`GEMINI_ERROR`)**: read the saved JSON for the error message and explain it plainly. Common causes: an invalid key (set it up again), a private or unlisted video (only public videos work), the daily free limit (8 hours of YouTube video per day; try again tomorrow), or a model that's been renamed (run again with `YT_GEMINI_MODEL=gemini-flash-latest` in front of the command).

On Windows without bash, make the same request in PowerShell: a POST to `https://generativelanguage.googleapis.com/v1beta/interactions` with the header `x-goog-api-key` (read from the key file, never typed out) and the JSON body built in the script.

### One-time key setup

Tell the user:

1. Go to **https://aistudio.google.com/apikey** and sign in with a Google account.
2. Click **Create API key** (accept Google's terms if asked), then copy the key.
3. Either **paste it here in the chat**, and you'll save it on their computer only, or ask you to **open the key file** so they can paste it in and save it themselves.

The key file is `~/.config/youtube-watch/gemini-key` (the script creates it, readable only by the user). If they paste the key in chat, write it as the only line of that file with your file-writing tool. If they'd rather do it themselves, open the file in their text editor (`open -t` on macOS, `notepad` on Windows, `xdg-open` on Linux).

Never print the key, repeat it back, or put it in a shell command. The script reads it from the file.

## 4. Save it

Save each transcript as a Markdown file in the working folder, named with a number and a short slug (for example `01-letting-go-transcript.md`), with this header:

```markdown
# <video title>

- URL: <url>
- Length: <m:ss>
- Source: YouTube auto-generated captions (<method>), copied <today's date>

## Transcript

[0:00] ...
```

If the user wants a **Google Doc** and a Google Drive connector is available, also put the transcripts in one Doc: build simple HTML (an `<h1>` title, a linked list of the videos, then an `<h2>` per video with its transcript lines as `<p>` paragraphs) and create it with Drive `create_file` using `contentMimeType: "text/html"`. Read the Doc back to check every video made it in, then give the user the link. If there's no Drive connector, say so and keep the Markdown files.

## 5. Do something with it

Then do whatever the user asked for. If some videos were skipped (no captions and no Gemini), list them first. Then: a summary, key points with timestamps, quotes, show notes, social posts, blog drafts, workbook ideas. Base it only on the transcript, and cite timestamps so the user can check them.
