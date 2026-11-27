# Fiordland XFCE container

A Fiordland XFCE desktop streamed to the browser with [Selkies](https://github.com/selkies-project/selkies). Built from a pinned Arch archive snapshot, so every pull of a tag is the same tested image.

```sh
read -rsp "Desktop password: " PASSWORD; export PASSWORD; echo
docker run -d --shm-size=2g -p 127.0.0.1:8080:8080 -e PASSWORD ghcr.io/Fiordland-Linux/fiordland-xfce:latest
```

Open `http://localhost:8080` and log in as `fiord` with the password.

Also published as a rootfs tarball: https://fiordlandlinux.org/iso/container/fiordland-xfce-latest.tar.zst (`.sha256` beside it).

## GPU encoding

NVIDIA (NVENC) is picked up automatically when the GPU is handed to the container:

```sh
read -rsp "Desktop password: " PASSWORD; export PASSWORD; echo
docker run -d --gpus all --shm-size=2g -p 127.0.0.1:8080:8080 -e PASSWORD ghcr.io/Fiordland-Linux/fiordland-xfce:latest
```

This needs the NVIDIA Container Toolkit on the host. `NVIDIA_DRIVER_CAPABILITIES=all` is set in the image. AMD VA-API is in Mesa and is used with `--device /dev/dri`; Intel needs `intel-media-driver`, which is not included. The desktop user is added to the groups that own the GPU device nodes at start. Without a GPU it falls back to x264 on the CPU.

Check what it chose with `docker logs <container> 2>&1 | grep -i -E "nvenc|pixelflux|starting"`.

GeForce cards cap concurrent NVENC sessions (8 on current drivers); one desktop is one session.

## Settings

The LinuxServer.io names work, so it drops in where their Selkies images ran.

| Variable | Default | |
|---|---|---|
| `PASSWORD` | unset | Login password. Required unless an authenticating proxy is explicitly enabled. |
| `FIORDLAND_PROXY_AUTH` | `0` | Set to `1` only behind an authenticating proxy to allow passwordless web access. |
| `CUSTOM_USER` | `fiord` | Desktop user name, also the login name. |
| `PUID` / `PGID` | `1000` | User and group id of the desktop user. |
| `CUSTOM_PORT` / `SELKIES_PORT` | `8080` | Port the web client and stream listen on. |
| `SUBFOLDER` | `/` | Path prefix when reverse-proxied under a subpath. |
| `TITLE` | `Fiordland` | Browser tab and dashboard title. |
| `TZ` | UTC | Time zone. |
| `SELKIES_ENABLE_HTTPS` | `false` | Serve HTTPS; a self-signed certificate is made unless `SELKIES_HTTPS_CERT`/`SELKIES_HTTPS_KEY` are given. |
| `SELKIES_FRAME_ANCESTORS` | `'self'` | Origins allowed to embed the desktop in an iframe, e.g. `https://portal.example.com`. |
| `SELKIES_ALLOWED_ORIGINS` | same origin | Origins allowed to open the stream websocket when the page is served from elsewhere. |
| `SELKIES_ENCODER` | `h264enc` | Video encoder; GPU is used for it when present. |

Every other `SELKIES_*` variable is passed to Selkies as-is; `selkies --help` lists them.

## Persistence

Mount a volume at `/config` and it becomes the user's home, owned by `PUID`/`PGID`. Without it, files live in `/home/fiord` and go away with the container.

## Behaviour

- Logging out of XFCE starts a fresh desktop instead of leaving a black screen.
- Shut Down and Restart are disabled; stop the container from the host.
- Firefox starts without first-run tabs, telemetry, or sponsored tiles.
- `fiord` has sudo; `pacman` works but pulls from the pinned snapshot, so pull a newer image to update.

## Building

`./build.sh` on an Arch-based host with `pacstrap`, `podman`, and `makepkg`. `SNAPSHOT=YYYY/MM/DD` pins the archive date (default: two days ago).
