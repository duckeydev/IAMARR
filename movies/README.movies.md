Movie Arr Stack

This directory contains a Docker Compose configuration tailored for managing and streaming movies.

Included Services
- Radarr (`http://localhost:7878`): Movie library manager to find, download, and organize movies.
- Bazarr (`http://localhost:6767`) (optional): Subtitle manager that integrates with Radarr/Sonarr.
- Jellyfin (`http://localhost:8096`) (optional): Media server to stream movies to clients.
- Overseerr (`http://localhost:5055`) (optional): Requests front-end for users to request movies.
- Sonarr (`http://localhost:8989`) (optional): TV show manager (included as an optional service).

Folder structure used
- `config/` - Per-app config folders.
- `data/torrents/movies` - Downloads for movie torrents.
- `data/media/movies` - Final movie library (Radarr should be configured to move/rename here).
- `data/media/tv` - Optional TV library (for Sonarr).

How to use
1. If you already run `Prowlarr` and `qBittorrent` in your music stack, prefer reusing them: add `qBittorrent` as Radarr's download client and `Prowlarr` as its indexer manager. Running duplicate indexers/downloaders can cause conflicts.
2. Start the movie stack (or just the services you want):

```bash
# start the whole movie stack
cd /home/ducky/Desktop/Arr
docker compose -f docker-compose.movies.yml up -d
```

3. Configure Radarr:
   - Set the Root Folder to `/movies` (maps to `./data/media/movies`).
   - Add your download client (qBittorrent) and path `/downloads`.
   - Add Prowlarr as an indexer if you run it already.
4. Configure Bazarr to connect to Radarr/Sonarr for subtitle fetching.
5. Point Jellyfin to `/media` to add both `movies` and `tv` libraries.

Permissions
The compose uses `PUID=1000` and `PGID=1000` by default. If you get permission errors, run `id` and update the compose files accordingly.
