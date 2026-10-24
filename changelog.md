# ZeroTier KSU v1.1.0

**Upgrade notice: shell command mounting defaults to OFF for new installs and legacy upgrades without a saved preference.** After reboot, use `/data/adb/zerotier/zerotier` from a root shell and update scripts that relied on short command names. Previously saved mount choices are preserved.

- Use a separate main-table policy priority for this service so stopping it preserves WireGuard and other modules; add lifecycle routing regression coverage.
- Update the bundled ZeroTier core from `1.16.0` to the official `1.16.2` release tag, pinned to commit `fc5c3ec22090b5b2a0f274e863651fe9ca489bf4`.
- Add the module-wide **Shell Command Mount** switch and `zerotier mount {enable|disable|status|supported}` CLI commands; switching requires a reboot.
- Disable the option and reject CLI enable requests on KernelSU without an enabled mounting metamodule. Magisk/APatch keep their built-in mounting support.
- Use data-directory tools for WebUI, boot autostart and internal calls so the service remains available without system mounts.
- Preserve existing service configuration and identity data, and add upgrade/provider/private-tool/boot regression coverage to build and release checks.
- Install data-directory `zerotier-cli` and `zerotier-idtool` aliases alongside `zerotier-one`, and remove only these tool aliases on uninstall.
- Share a pinned-source ARM64 core build script across build/release workflows; fetch the tag explicitly and verify its resolved commit to avoid same-name release branches.
- Cache compiled cores by source, script, compiler/static-library fingerprints and flags; verify cached hashes and ELF architecture before reuse.
- Select embedded SSO/controller build targets explicitly instead of patching upstream makefiles.
- Avoid duplicate system tools by creating mount payloads only on demand; synchronize choices with pending upgrades and roll back failed payload preparation.
- Add core integrity/cache-key regression tests and pin CI runners to Ubuntu 24.04.
- Publish updater metadata only after the uploaded public ZIP matches the local package; preserve stable metadata on failures or prereleases, and retry concurrent branch updates without downgrading versions.

Core version: `1.16.2`

# ZeroTier KSU v1.0.0

- Initial release
- ZeroTier daemon management (start/stop/restart)
- Network join/leave via CLI and WebUI
- Peer list with latency and path info
- Planet and Moon management in WebUI
- Boot auto-start with toggle
- KSU/APatch WebUI with config editor
- KSU module description overlay with status and IP

Core version: `1.16.0`
