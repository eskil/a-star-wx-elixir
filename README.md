# AstarWx

## Mix

```
mix new a-star-wx-elixir --app astarwx --module AstarWx --sup
```

## Description

A polygon is a list of `{x, y}` tuples that represent screen
coordinates. In elixir, it looks like

```elixir
polygon = [{x, y}, {x, y}, ...]

The screen coordinate `0, 0` is upper left the x-axis goes
left-to-right and y-axis top-to-bottom.

The polygon is loaded from a json file, and looks like

```json
{
  "polygons": [
    "main": [
      [x, y], [x, y], [x,y]...
    ],
    "hole1": [
      [x, y], [x, y], [x,y]...
    ],
    "hole2": [
      [x, y], [x, y], [x,y]...
    ]
  ]
}
```

The `main` polygon is the primary walking area - as complex as it
needs to be. Subsequent polygons are holes within it.

If a polygons ins't closed (last `[x, y]` equals the first), it
will be closed for you.

The tool will display the polygon as a blue outline with a blue crosshair
at each vertice.
