# AstarWx

## Mix

```
mix new a-star-wx-elixir --app astarwx --module AstarWx --sup
```

## Polygon map

A polygon is a list of `{x, y}` tuples that represent screen
coordinates. In elixir, it looks like

```elixir
polygon = [{x, y}, {x, y}, ...]
```

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

Polygons don't need to be closed (last `[x, y]` equals the first),
that will be handled internally. The rendered polygons will be closed,
and datastructures will operate on open/closed as necessary.

The tool will display the polygon as a blue outline with a blue crosshair
at each vertice.

## Graph

The graph is a map from `edge` to a list of `{edge, cost}`;

The `cost` is the `Vector.distance` between the two. This allows other
implementation to use a custom cost.

An `edge` initially was a tuple of coordinates of a walk vertice, `{x,
y}`. Using indexes into the source (list of walk vertices) seems
better. If the vertices were more complex things, not just `{x, y}`,
eg. had hot spot names and associated actions, we'd want to refer back
to them anyway.

So the input is;

```elixir
vertices = [{x1, y1}, {x2, y2}, {x3, y3}...]
```
And the graph worked on is

```elixir
%{
  1 => [
    {2, 150},
    {3, 70},
  ],
}
```


## Todo

- [ ] Align on a single `polygon, point` argument order
- [ ] The polygon "name" thing needs to be addressed - it def must not be in geo.ex
- [ ] should walkgraph use indexes or points? Ie. `{{edge_1_idx, edge_2idx}, weight}` or `{{x1, y1}, {x2, y2}, weight}`?
