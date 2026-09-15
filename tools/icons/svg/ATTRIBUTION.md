# Vendored icon artwork

These SVGs come from [game-icons.net](https://game-icons.net) and are the source
artwork for the glyphs Material Icons has nothing for — game species, animal
sign, and a handful of terrain and access features. They are checked in rather
than downloaded at build time so that
`tools/icons/build_owm_icon_font.py` is reproducible offline and a change to the
artwork shows up in a diff.

## Licence

Creative Commons Attribution 3.0 Unported (CC BY 3.0),
<https://creativecommons.org/licenses/by/3.0/>.

Attribution is a condition of use, not a courtesy, so it is surfaced in the app
on the About screen and recorded in `docs/datasets.md`. Every file below is CC BY
3.0; none of the picks are from the two contributors who release as CC0, so
there is no file here that may be used unattributed.

The folder each file sits in is its author, which is how the upstream archive
identifies authorship, and it is the only record of who is owed credit. Keep the
folders when adding artwork.

## Authors and files

| Author | Files |
| --- | --- |
| Caro Asercion | `boar`, `canadian-goose`, `deer` |
| Cathelineau | `flying-trout` |
| Delapouite | `bear-head`, `beaver`, `berry-bush`, `binoculars`, `cave-entrance`, `deer-track`, `farm-tractor`, `forest`, `gate`, `ladder`, `rabbit`, `squirrel`, `swamp`, `tire-tracks`, `watchtower`, `waterfall`, `well` |
| Lorc | `acorn`, `animal-skull`, `bridge`, `campfire`, `feather`, `mushroom`, `wolf-head` |

Credit line, as the upstream licence asks it to be worded:

> Icons made by Caro Asercion, Cathelineau, Delapouite and Lorc,
> available at https://game-icons.net

## Shape of the files

Each is a 512x512 `viewBox` holding a black background rectangle
(`M0 0h512v512H0z`) followed by the white ink paths. The build strips the
background and keeps the ink, so an added file needs no hand editing.
