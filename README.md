# dmsbtc — Bitcoin price monitor for DankMaterialShell

**[English](README.md)** · [Español](README.es.md)

A plugin for DankMaterialShell (`dms`) that shows the Bitcoin price in your bar and adapts to your theme, your currency and your refresh interval.

![Plugin screenshot](dmsbtc.png)

## What it does

*   **Price in the bar:** refreshes every minute by default, configurable from 15 seconds to 10 minutes.
*   **Provider failover:** falls back through CoinGecko → Coinbase → Blockchain.info. A provider that cannot quote the currency you picked is discarded instead of showing you a price in a different one.
*   **Trend colouring:** turns green with ▲ or red with ▼ for as long as you configure, when the price moves.
*   **Popout:** click the pill for the live price, the delta since the previous reading, a sparkline of the recent readings, the provider that answered, and buttons to refresh, copy the price or open CoinGecko.
*   **Theme-aware:** uses DMS colours, sizes and spacing, so it stays readable on light and dark themes, with any accent colour.
*   **No dependencies:** no `curl`, no external binaries.

## Install

1.  Copy this folder to `~/.config/DankMaterialShell/plugins/dmsbtc/`.
2.  `dms restart`, then enable it from Settings → Plugins.

## Configuration

Everything is configured from **Settings → Plugins → BTC Price Monitor**. There is no need to touch the QML.

| Setting | Default | What it does |
| --- | --- | --- |
| Currency | USD | USD, EUR, GBP, BRL, ARS, CLP, JPY |
| Refresh every | 60 s | How often the price is polled (15 s to 600 s) |
| Flash duration | 60 s | How long the green/red lasts after a change (0 = no flash) |
| Show trend | Yes | Adds ▲ or ▼ next to the price when it moves |
| Price in vertical bar | Yes | Abbreviated price under the icon |
| Colour when up | Theme success | Used for the price and the ▲ arrow |
| Colour when down | Theme error | Used for the price and the ▼ arrow |
| ₿ icon colour | `#F7931A` | Bitcoin orange, or the theme's primary colour |

## Development

The plugin hot-reloads, so there is no need to restart the shell:

```bash
dms ipc call plugins reload btcPriceMonitor   # reload after editing the QML
dms ipc call plugins list                     # list the loaded plugins
dms ipc call plugins status btcPriceMonitor   # plugin status
```

For QML autocompletion and type checking, open the project inside a clone of [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) with the `dank-qml-common` submodule.

## Author

by kastor
