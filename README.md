# Nexwall Firewall for the Banana Pi OpenWrt One

Build of Nexwall Firewall (an OpenWrt-based firewall distribution) for the Banana Pi OpenWrt One (MediaTek MT7981B, 1 GiB RAM,
256 MiB SPI-NAND with a 16 MiB NOR recovery, NVMe M.2 slot, Wi-Fi 6). Derived from `nexwall/firewall-msp` (version in
`build.conf.defaults`); the changes against it are listed in `FORK-CHANGES.md`. The BPI-R3 and BPI-R4 boards are in
`nexwall/nexwall-bananapi-fw`.

Use case: remote unit (small branch or site firewall). Boot, partitions and mounts are the ones of the upstream OpenWrt image
(this repository does not change them); data (threat lists, web categories, logs, proxy cache) belongs on the NVMe disk,
mounted by the storage package as on the x86 firewall. The NOR recovery image must stay untouched: back up both flashes
before the first write.

## Build

```
podman, a user without root, 8 GiB RAM or more, 60 GiB of disk or more
./build-nexwall.sh
```

`TARGET` defaults to `mediatek_filogic`. The images are written to `bin/targets/mediatek/filogic/`. Set `MAKE_JOBS` lower on
hosts with little RAM (the LLVM build step is the heaviest). Package signing keys (`private-key.pem`, `public-key.pem`) are
not part of the repository.

## Vendor binaries

The license core, the web protection service, the web interface and the traffic-engine and IPS plugins are published as
binaries; the recipes pin one SHA-256 per architecture and stop the build when an enabled component has no pin for
`aarch64`. Without them the image is a community build for that component. See `docs/BOARDS.md`.

## License

Same as `nexwall/firewall-msp` (see `LICENSE` and `NOTICE.md`).
