# Circle flags

Vendored from [HatScripts/circle-flags](https://github.com/HatScripts/circle-flags)
(MIT — see `LICENSE`), the same source the Pathors main app vendors from, so a
language looks the same wherever you meet it.

Only the flags some portal locale actually maps to are kept here. To add a
language, copy its file from the upstream repo and add the locale to the map.

They are served as separate files rather than inlined into the page on purpose:
every upstream flag defines `<mask id="a">`, so inlining more than one into a
single document makes them clip each other.

`PortalLocalesHelper::LOCALE_FLAGS` maps a portal locale to a file here. A locale
with no entry falls back to the globe icon rather than to a wrong flag.
