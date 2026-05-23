All-in-One Arr Stack

This compose brings together the full Arr ecosystem for media: indexers, download clients, managers and media servers.

Included Services (examples):
- Prowlarr: Indexer manager (9696)
- qBittorrent: Torrent client (8080)
- Transmission: Alternative torrent client (9091)
- Lidarr: Music manager (8686)
- Radarr: Movie manager (7878)
- Sonarr: TV manager (8989)
- Bazarr: Subtitle manager (6767)
- Navidrome: Music streaming (4533)
- Jellyfin: Media server (8096)
- Overseerr: Requests front-end (5055)

Start the whole stack:

```bash
cd /home/ducky/Desktop/Arr
./setup.sh
```

Notes:
- The compose uses `PUID=1000`/`PGID=1000`; change if needed.
- If you already run per-domain stacks (musicOnly/movies), prefer reusing `Prowlarr` and download clients to avoid duplicates.
 - If you already run per-domain stacks (musicOnly/movies), prefer reusing `Prowlarr` and download clients to avoid duplicates.

Automation note:
- `setup.sh` will create a `.env` with your `PUID`/`PGID` and start the full stack. It waits for the main web UIs to respond and prints next steps.
- I can further automate wiring apps (Radarr/Lidarr/Sonarr -> Prowlarr and download clients) but that requires the initial API keys/passwords which are created during first-run in the web UIs. If you want full automation, run the stack once, share the generated API keys and I will script the rest.
