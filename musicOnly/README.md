# Music Arr Stack

This directory contains a fully functional Docker Compose setup for a music-focused "Arr" stack. 

## Included Services
* **Lidarr** (`http://localhost:8686`): The core library manager to find, download, and organize music.
* **Prowlarr** (`http://localhost:9696`): Centralized indexer manager for lidarr to search torrent trackers.
* **qBittorrent** (`http://localhost:8080`): The download client to fetch the requested torrents. 
* **Navidrome** (`http://localhost:4533`): A lightweight music streaming server compatible with Subsonic clients (like Symfonium on Android or play:Sub on iOS).

## Folder Structure (TRaSH Guides Standard)
This configuration uses a unified `/data` folder structure to take advantage of atomic moves and hardlinking, significantly saving disk space and speeding up file processing.

* `config/` - Contains all application databases and settings.
* `data/torrents/music` - Where qBittorrent stores downloaded music files.
* `data/media/music` - Where Lidarr organizes and renames your final music library (and where Navidrome reads it).

## How to Start
1. Ensure Docker and Docker Compose are installed on your machine.
2. Open a terminal in this directory.
3. Run `docker-compose up -d` to create the folders and start the stack in the background.

## Initial Setup
1. **Prowlarr**: Go to `http://localhost:9696`, setup your indexers/trackers. Add Lidarr under Settings -> Apps so it syncs the trackers automatically.
2. **qBittorrent**: Default credentials are usually `admin` and `adminadmin` (it will generate a temporary password in the docker configuration logs if that doesn't work). Make sure the default download path is set to `/data/torrents/music`.
3. **Lidarr**: Go to `http://localhost:8686`. 
   - Add qBittorrent as your Download Client.
   - Set up your Root Folder as `/data/media/music`.
4. **Navidrome**: Go to `http://localhost:4533` and create your admin account. It's already configured to read from your Lidarr output folder!
