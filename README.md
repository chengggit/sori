### Local reading

In the desktop app, open **My Library** and choose **Import** to add a UTF-8
`.txt` file up to 2 MiB. Select the imported document to read it. Sori stores a
copy in its local SQLite database so the document stays available after restart.

### YouTube discovery

Sori can open a YouTube video link from Home without an API key. For automatic
discovery and search, enable YouTube Data API v3 in a Google Cloud project, then
set `VITE_YOUTUBE_API_KEY` in `.env.local` before starting or building Sori.
Use an API-restricted key for local development. This build variable is visible
in the desktop bundle, so keep any shared production credential server-side.
The player requires an internet connection. Use **Open on YouTube** if a video
cannot play in the embedded player.
