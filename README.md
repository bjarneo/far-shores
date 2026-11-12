# Far Shores

Far Shores is a pixel-art fishing game for Godot 4.7. You travel to 14 places around the world and catch the fish that live there. Each place has its own scenery, water, weather, music and 6 or 7 real species. The game uses the engine of Little Reef: the low-resolution viewport, the runtime sprite builder, the pixel UI and the synthesized audio.

## Play in the browser

Play the web build at <https://bjarneo.github.io/far-shores/>. It works on desktop and on phones.

## Run the game

Open the project in the Godot 4.7 editor and press F5. To run it from a terminal, use this command:

```sh
godot --path .
```

## How to fish

1. Hold the action button, or hold anywhere on the water, to charge a cast. Let go to throw the lure.
2. Let the lure sink to the depth where the fish swim. Hold to reel it in slowly.
3. A fish that likes your bait comes to look. A question mark shows while it nibbles. Do not strike yet.
4. When the exclamation marks show, press at once to set the hook.
5. Hold to reel the fish in. Let go when the line meter turns red, or the line snaps. A slack line lets the fish spit the hook.
6. Sell the fish or release it. Legendary fish always go back to the water, and the fishing club pays a bounty.

## Controls

| Action | Desktop | Touch |
| --- | --- | --- |
| Cast, strike and reel | Hold `Space`, the action button, or the left mouse button on the water | Hold the action button or the water |
| Change bait | Keys `1` to `5`, or the bait button | The bait button |
| World map | `M`, or the MAP button | The MAP button |
| Fish book | `B`, or the BOOK button | MENU, then BOOK |
| Sell or release a catch | `Enter` to sell, `R` to release | The SELL and RELEASE buttons |
| Close a panel | `Esc` | The CLOSE button |
| Name a fish | Point at it | Tap it |
| Full screen | `F11` | The full-screen button in the top bar, or in MENU on a thin screen |

## The world

| Place | Country | Platform | Legend |
| --- | --- | --- | --- |
| Lofoten | Norway | Pier | Atlantic Halibut |
| Loch Ness | Scotland | Rocks | Ferox Trout |
| Amalfi Coast | Italy | Stone quay | Atlantic Bluefin Tuna |
| Suruga Bay | Japan | Pier | Giant Oarfish |
| Kootenay Lake | Canada | Pier | White Sturgeon |
| Florida Keys | United States | Flats skiff | Tarpon |
| Nile at Giza | Egypt | Felucca | Nile Perch |
| Li River | China | Bamboo raft | Chinese Sturgeon |
| Ayutthaya | Thailand | Longtail boat | Mekong Giant Catfish |
| Amazon River | Brazil | River bank | Arapaima |
| Great Barrier Reef | Australia | Charter boat | Black Marlin |
| Cabo San Lucas | Mexico | Charter boat | Striped Marlin |
| Ilulissat | Greenland | Ice floe | Greenland Shark |
| Ross Sea | Antarctica | Hole in the sea ice | Antarctic Toothfish |

Each place keeps local time from its real UTC offset. When you fly from Norway to Japan, the clock jumps 8 hours. Some fish bite only at night, at dawn or at dusk. Rain and snow make fish bite more often.

## Gear and bait

- The rod sets the cast distance and the time you have to strike.
- The reel sets how fast you bring the line in.
- The line sets how hard a fish can pull before the line snaps.
- Each species likes 1 or 2 baits. The fish book shows them. A worm works on most fish but not well. The big plug draws large and rare fish only.

## Play on a phone

The web build works in portrait and in landscape. The layout changes when you turn the phone.

- On a thin screen, SHOP, BOOK and AWARDS move into MENU. The sound button moves there when the screen is less than 400 pixels wide.
- On a short screen, such as a phone held sideways, the bars get smaller. The fight meter moves over the sky, and the catch card puts the fish beside the text.
- Android browsers and iPad Safari show a full-screen button. iPhone Safari cannot show a page in full screen. To play without the browser bars on an iPhone, tap Share, then Add to Home Screen.
- The screen stays on while you fish. It can turn off 2 minutes after your last touch.
- One scene pixel always covers a whole number of screen pixels, so the pixel art stays sharp on every screen.

## Export for the web

The web build is single-threaded. It runs on any static host and does not need cross-origin isolation headers.

1. Install the Godot 4.7.2 web export templates. The export needs `web_nothreads_release.zip` and `web_nothreads_debug.zip` in `~/.local/share/godot/export_templates/4.7.2.stable/`.
2. Export the build. The script also copies the web app manifest and icons from `web_extra/`:

   ```sh
   ./tools/export_web.sh
   ```

3. Test the build on your computer:

   ```sh
   python3 -m http.server 8765 --directory build/web
   ```

   Then open `http://127.0.0.1:8765/`.

4. To publish the build, push to `main`. The workflow in `.github/workflows/pages.yml` exports the build and deploys it to GitHub Pages.
5. To use a different host, upload the files in `build/web` to it. Turn on gzip or Brotli compression on the host. Compression makes `index.wasm` go from 39 MB to 10 MB, so the game loads faster on a phone.

## Debug flags

Pass these after `--` on the command line:

| Flag | Effect |
| --- | --- |
| `--fresh` | Deletes the save before the game starts |
| `--loc=amazon` | Starts at a place. Use a key from `Places.ORDER` |
| `--hour=19.5` | Sets the local hour |
| `--wx=rain` | Sets the weather: `clear`, `cloud`, `rain`, `snow` or `fog` |
| `--coins=5000` | Sets the coins |
| `--shot=out.png` | Saves a screenshot and quits |
| `--tour=DIR` | Saves a screenshot of every place into `DIR` and quits |
| `--sheet=out.png` | Saves every fish sprite into one image |
| `--autoplay=300` | Plays by itself for 300 seconds of game time and prints each catch |
| `--perf` | Prints the frame rate and the script time every 5 seconds |
| `--vsize=390x664` | Shows the layout of a screen of that size in UI pixels, such as a phone |

Example:

```sh
godot --path . -- --fresh --loc=reef --hour=18 --shot=/tmp/reef.png
```

## Save data

The game saves to `user://far-shores-save.json`. In a browser, this file is in IndexedDB for the page's origin. To start again, open AWARDS and use RESET GAME.

## Project layout

- `scripts/game.gd` holds the simulation: time, weather, fish, the cast, the fight, the economy and saving.
- `scripts/species.gd` holds the 97 species. `scripts/places.gd` holds the 14 places.
- `scripts/sprites.gd` builds the fish, the angler, decor, flags and bait icons at runtime.
- `scripts/scenery.gd` paints the backdrop of each place.
- `scripts/sky_view.gd`, `scripts/scene_view.gd` and `scripts/overlay_view.gd` draw the world into a low-resolution viewport.
- `scripts/hud.gd` is the interface. `scripts/map_view.gd` is the world map.
- `scripts/world_data.gd` is a 1-degree land mask made from Natural Earth 1:50m land data, which is in the public domain.

## Credits

- Pixelify Sans and Silkscreen fonts, under the SIL Open Font License. The license files are in `fonts/`.
- Land outlines from Natural Earth, public domain.
