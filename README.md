\
# Minecraft Server Manager v3

A shell-first, config-driven Minecraft server management platform for Ubuntu/Linux.

## What this includes

- Multi-server config model
- Active-server switching
- `systemd` unit and timer generation
- `tmux`-based supervised runtime
- Crash-loop protection and manual unlock
- Local backups with JSON manifests
- Backup verification and retention cleanup
- Restore with staging and pre-restore safety snapshot
- Health / doctor / status commands
- Unified `mcadmin` interface
- Bootstrap installer for dependencies and directories

## Quick start

```bash
cd /path/to/minecraft-v3-full
./tools/bootstrap-host.sh
./tools/create-server-config.sh TestServer --template blank-neoforge --activate
./scripts/mcadmin doctor
./scripts/mcadmin switch TestServer --start
./scripts/mcadmin status
```

## Important note

The platform is fully implemented and bootstraps itself, but it cannot manufacture a real Minecraft modpack/server binary for you.  
To actually launch a real server, place real server files in either:

- `templates/<template-name>/`
- or `servers/<server-name>/`

The default `blank-neoforge` template includes a placeholder `startserver.sh` so the platform itself can be tested end to end.

## Main commands

```bash
./scripts/mcadmin status
./scripts/mcadmin status --json
./scripts/mcadmin doctor
./scripts/mcadmin start
./scripts/mcadmin stop
./scripts/mcadmin restart
./scripts/mcadmin backup now
./scripts/mcadmin restore list
./scripts/mcadmin restore latest
./scripts/mcadmin switch TestServer --start
./scripts/mcadmin timers
./scripts/mcadmin logs runtime
./scripts/mcadmin health
./scripts/mcadmin unlock-crash
./scripts/mcadmin clone SRC DST
./scripts/mcadmin archive NAME
./scripts/mcadmin delete NAME
./scripts/mcadmin test all
```
