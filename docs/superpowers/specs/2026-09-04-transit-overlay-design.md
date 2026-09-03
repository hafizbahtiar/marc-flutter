# Klang Valley Rail Transit Overlay

Date: 2026-09-04
Status: approved for implementation

## Problem

The map's "Transport" tile type does not show public transport. It maps to
the OpenFreeMap `positron` style (`osm_tile_source.dart`), a minimal grey
CARTO basemap whose rail treatment is:

- `railway` painted `#dddddd` (near-invisible light grey), and
- `railway_transit` — subway/LRT/monorail — gated behind `minzoom: 16`, so
  it does not exist until the user is zoomed almost to street level.

The layer also credits MeMoMaps, a raster provider that is never fetched:
`AppMap._styleString` reads only `vectorStyleUri`, so `urlTemplate` and
`subdomains` on `MapTileSource` are dead code left over from a `flutter_map`
era. Nothing outside `map_tile_source.dart` and `osm_tile_source.dart` reads
either member.

So "Transport" today is a plain grey basemap wearing a bus icon, attributed
to a provider it does not use.

## What the vector tiles already give us, and what they do not

Decoding a real OpenFreeMap tile over KL Sentral (z14) confirms the
`transportation` source-layer carries `subclass` values `subway`,
`light_rail` and `monorail`, and the `poi` layer carries named stations.
Restyling those is free — no new network, no new data.

But per-line identity is not there. The `transportation_name` schema
declares `route_1_colour` … `route_16_colour`, yet the KL tile contains
**zero** colour values, and its only `route_*` entries are pedestrian
corridors (`MRT Linkway`), not rail lines. Mode-based colouring
(subway/light_rail/monorail) is achievable from tiles; "Kajang Line green,
Kelana Jaya Line red" is not.

That gap is why this spec uses GTFS rather than tile restyling.

## Data source: data.gov.my Prasarana GTFS

`https://api.data.gov.my/gtfs-static/prasarana?category=rapid-rail-kl`
(80 KB zipped) contains everything the overlay needs:

| route_id | category | name                  | colour    | shape pts |
|----------|----------|-----------------------|-----------|-----------|
| AG       | LRT      | LRT Ampang Line       | `#e57200` | 210       |
| KJ       | LRT      | LRT Kelana Jaya Line  | `#D50032` | 682       |
| PH       | LRT      | LRT Sri Petaling Line | `#76232f` | 590       |
| KGL      | MRT      | MRT Kajang Line       | `#047940` | 580       |
| PYL      | MRT      | MRT Putrajaya Line    | `#FFCD00` | 714       |
| MR       | MRL      | KL Monorail Line      | `#84bd00` | 192       |
| SA       | LRT      | LRT Shah Alam Line    | `#00A9E0` | 549       |
| BRT      | BRT      | BRT Sunway Line       | `#115740` | 123       |

Official route colours, full `shapes.txt` geometry, and 187 stop rows with
name, coordinates, `route_id`, and an `isOKU` accessibility flag. 151 of
those rows belong to the seven rail lines.

**BRT Sunway is excluded** — it is a bus service, and the seven rail lines
are the scope.

Two quirks of the feed that the pipeline must handle:

1. `shapes.txt` holds two shapes per route (direction 0 and 1). One is
   enough to draw the line; the pipeline takes direction 0.
2. `stops.txt` has a `geometry` column whose every value is the literal
   string `[object Object]` — a bug in their export. Ignore it and use
   `stop_lat` / `stop_lon`.

### Interchange stations must be merged

The 151 rail stop rows resolve to 132 unique stations: 19 appear once per
serving route. Masjid Jamek appears three times (AG, KJ, PH); Titiwangsa
four (AG, PH, PYL, MR). Their coordinates are close but not identical —
Maluri's two rows sit ~40 m apart.

Rendered unmerged, an interchange is a pile of overlapping dots and a tap
returns one arbitrary route. The pipeline merges by upper-cased name,
collects the serving `route_id`s, and positions the station at the
centroid.

Merging by name is only safe while names are unique per station, so the
pipeline **fails loudly** if a merged cluster spans more than 300 m. The
worst real cluster in the current feed deviates 147 m from its centroid, so
that threshold has roughly 2x headroom — it is a guard, not a formality. A
silent merge of two genuinely different stations that share a name would
put a station in the wrong place, and that is worse than a failed build.

### Known gap: KTM Komuter

Klang Valley commuters count KTM Komuter as part of the network, and it is
absent here. The separate KTMB feed
(`https://api.data.gov.my/gtfs-static/ktmb`, 47 KB) has `routes.txt` with
official colours (Seremban Line `#3C5A9F`, Port Klang Line `#DC2420`) and
`stops.txt` — but **no `shapes.txt` at all**, so there is no line geometry
to draw.

Joining its stops in `stop_times` order would produce straight lines cutting
across the city, which is both wrong and visibly wrong. This spec therefore
ships without KTM. Options for a later pass are recorded in
`test/shared/ui/map/docs/TRANSPORTATION.md`.

## Build-time pipeline

`tool/build_transit_assets.dart`, run manually with `dart run`. It is not
part of the app and never runs on a device.

Steps: download the `rapid-rail-kl` feed (or read a local zip via `--zip`),
drop non-rail and `status != valid` rows, take direction-0 shapes, merge
interchanges, and write two GeoJSON files.

Route colour is written into every feature's properties, so styling is
fully data-driven (`["get", "color"]`) and the runtime needs no lookup
table.

Output, listed individually in `pubspec.yaml` (its existing comment already
warns that directory entries are not recursive):

- `assets/transit/rail_lines.geojson` — 71 KB, 7 LineStrings
- `assets/transit/rail_stations.geojson` — 20 KB, 132 merged stations

~22 KB gzipped together. Bundling was chosen over runtime fetching because
the data changes when a new line opens — a few times a decade, not weekly —
and a bundled asset has no offline path, no timeout, no corrupt-zip path,
and no on-device GTFS parser.

## The overlay abstraction

```dart
// lib/shared/ui/map/map_overlay.dart
abstract interface class MapOverlay {
  String get id;
  List<MapTileAttribution> get attributions;
  Future<void> install(MapStyleController style);
}
```

`MapStyleController` is a thin wrapper we own, exposing only what an
overlay needs — `addGeoJsonSource`, `addLineLayer`, `addCircleLayer`,
`addSymbolLayer`. Overlays never see a MapLibre type, so they are testable
against a recording double with no native map.

`MapTileSource` gains `List<MapOverlay> get overlays`. The `transport`
source returns `[TransitOverlay()]`; every other source returns `const []`.
That single line is the whole binding between the Transport tile type and
the transit layers.

This is deliberately more structure than "draw rail when transport is
selected" needs. It is what makes the binding a configuration rather than a
commitment: turning the overlay into an independent toggle later means
passing `overlays` directly to `AppMap` and adding a button — nothing
inside `TransitOverlay` changes.

`MapTileSource` is an `abstract interface class`, so implementers must
declare the new member. `OsmMapTileSource` and the test fakes are updated
accordingly.

## Lifecycle

Overlays install on `onStyleLoadedCallback`, not `onMapCreated` — sources
and layers require a loaded style.

Changing tile type changes `styleString`, which makes MapLibre discard every
layer and fire the callback again, so reinstallation is automatic. That is
why `MapOverlay` has no `remove()`: there is nothing to tear down, and a
teardown path would be dead code that drifts out of correctness.

## Rendering

Lines: zoom-interpolated width, `line-color` from the feature property,
`line-join: round`. Visible from roughly z9 — the whole point is that these
are legible before street level, unlike positron's z16 gate.

Stations: white circle with a route-coloured stroke from ~z11, name labels
from ~z13. Interchanges get a larger radius, since a station serving four
lines should not read the same as a terminus.

## Station tap

`onMapClick` → `queryRenderedFeatures` restricted to the station layer id →
a `showModalBottomSheet` card with the station name, a chip per serving
line in its official colour, and the `isOKU` accessibility status.

Deliberately not `showAppActionSheet`: that component is a list of actions
the user picks between, and this is a detail card with no actions. Reusing
it would mean fighting its contract.

## Attribution

`AppMap` merges `tileSource.attributions` with each installed overlay's
attributions, so "data.gov.my · Prasarana" appears exactly when the overlay
is live and disappears with it.

## Testing

- **Pipeline**: golden test over a small GTFS fixture, covering the
  interchange merge and the >300 m failure case.
- **Overlay**: a recording `MapStyleController` double asserts
  `TransitOverlay` registers the expected sources and layers.
- **Tile source**: `transport` declares the transit overlay; the others
  declare none.
- **Widget**: selecting Transport puts data.gov.my in the attribution;
  selecting Standard does not.

## Open question, blocking release but not implementation

The data.gov.my licence terms for redistributing their data inside a
shipped APK are **unverified**. Their terms page is JavaScript-rendered and
could not be read. Bundling government data is not something to assume is
permitted.

Build proceeds on the assumption that attribution suffices. Terms must be
confirmed before this ships.

## Out of scope

- Bus routes. `rapid-bus-kl` (1.7 MB), `rapid-bus-mrtfeeder` (2.0 MB) and
  `rapid-bus-penang` (4.5 MB) are 20-50x the rail feed, and hundreds of bus
  routes would bury the map without filtering.
- Live arrivals. The GTFS-realtime feeds are a separate subsystem.
- Routing or journey planning.
