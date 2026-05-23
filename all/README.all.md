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
./auto_wire.sh
```

Notes:
- The compose uses `PUID=1000`/`PGID=1000`; change if needed.
- `auto_wire.sh` now clones or updates the default repo, seeds Arr app credentials/API keys into config files, and then starts the stack.
- qBittorrent still prints its temporary Web UI password in logs on first boot; the script reminds you where to find it.
- If you already run per-domain stacks (musicOnly/movies), prefer reusing `Prowlarr` and download clients to avoid duplicates.

Automation note:
- `setup.sh` still starts the local compose stack with a minimal `.env` when you do not want the clone-and-seed bootstrap.
- `auto_wire.sh` is the hands-off path for the GitHub repo default and is the recommended entry point for a fresh install.
