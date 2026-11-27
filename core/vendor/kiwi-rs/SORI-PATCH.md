# Local Kiwi binding patch

Source: [kiwi-rs 2026.10.17](https://github.com/JAICHANGPARK/kiwi-rs/tree/32b5c5bd491cd804d4c82c7c1ed063df449d7f27),
copied from the published crate. The upstream license is included.

Only `src/runtime.rs::build_tag_name_cache` is changed. Upstream probes all 256
`u8` tag IDs, but Kiwi 0.24's `tagToString` indexes a smaller native table without
release-mode bounds checking. Initialization crashes on Windows; other platforms
also read outside that table.

The patch leaves the cache empty. Existing token parsing then gets each real
token's tag through `kiwi_res_tag` or `kiwi_res_tag_w`, avoiding invalid IDs and
preserving the upstream API and tag names.

Remove this copy and the Cargo patch when an upstream release fixes the probing.
Verify initialization, token tags, and UTF-16 offsets with the native Kiwi CTest
suite on all three platforms before removing it.
