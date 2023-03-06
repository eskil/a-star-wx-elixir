# AstarWx

A graphical demo of
[A-* 2d polygon map search](https://en.wikipedia.org/wiki/A*_search_algorithm)
in Elixir using WxWidgets.

## How to run

Assuming you have
[elixir installed](https://elixir-lang.org/install.html) (written with
1.14). Build and run;

```
mix deps.get
mix compile
mix run --no-halt
```
## How to run

The "world" is made up of a primary polygon. Inside of this there are
smaller polygons that make up holes. These are impassable.

[[/images/a-star-sample.gif|animated gif showing demo]]

* The start point is a *green crosshair*.
* The cursor position is a *red crosshair* if inside the main polution, *gray* if outside.
* Moving the mouse will show a line from start to the cursor.
  * It'll be *green* if the there's a line of sight.
  * It'll be *gray* if no, and there'll be a *small red crosshair* at
    the first blockage, and *small gray crosshair* all subsequent
    blocks.
* Holding down left mouse button will show full search graph in
  *bright orange* and a *thick green path* for the found path.
* Releasing the left mouse button resets the start to there.
  * You can place the start outside the main polygon.

## Internals

### Vectors

A vector is a tuple of positions, `{x, y}`.

In `lib/vector.ex` you'll find the basic vector operations (dot,
cross, length, add/sub) needed.

### Lines

A line is a tuple of vectors, `{{x1, y1}, {x2, y2}}`.

### Polygon

A polygon is a list of vertices (nodes) that are `{x, y}` tuples that
represent screen coordinates.

In elixir, it looks like

```elixir
polygon = [{x, y}, {x, y}, ...]
```

The screen coordinate `0, 0` is upper left the x-axis goes
left-to-right and y-axis top-to-bottom.

### Polygon map

The map is loaded from a json file, and looks like

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
needs to be.

Subsequent polygons (not named `main`) are holes within it.

Polygons don't need to be closed (last `[x, y]` equals the first),
this will be handled internally. The rendered polygons will be closed,
and datastructures will operate on open/closed as necessary.

## Graph

The graph is a map from `vertice` to a list of `{vertice, cost}`. This
is computed from the polygon map using a set of vertice. This set is
composed of;

* the main polygon's *concave*  (pointing into the world)
* the holes' *convex* (point out of the hole, into the world)


```elixir
vertices = [{x1, y1}=vertice1, {x2, y2}=vertice2, {x3, y3}=vertice3...]
```

And this is transformed to a graph, where each entry is used as a key
to a list of keys for other vertices. This transformation is not relevant
to the A* algorithm, but the result is the input;


An `edge` is a tuple of `{vertice1, vertice2, cost}`.

### A-star

An `vertice` is somewhat opaque to the algorithm, it just uses them as
keys.

By using whatever key the vetices list uses, we keep it simple, and
whatever manages the vertices can keep the initial list short, yet
also uses the keys to manage its own affairs.

The A* algorithm thus receives;

* `graph` to search

```elixir
graph = %{
  {x1, x2} => [
    {{x2, y2}, cost_fun({x1, y2}, {x2, y2})},
    {{x3, y3}, cost_fun({x1, y2}, {x3, y3})},
    ...
  ],
  vertice10 => [
    {vertice11, cost_fun(vertice10, vertice11)},
    ...
  ]
  ...
}
```

* `start` and `stop`, the vertices to find a path between.

* `heur_fun` function `vertice, vertice :: cost` computes heuristic cost. The common case in a 2D polygon map is the straight-line distance.

```elixir
fn a, b -> Vector.distance(a, b) end
```

The state it maintains

* `queue` priority queue / list `[vertice, vertice, ...]` sorted on the cost of the path from start to node to stop.
* `shortest_path_tree`, a map of edges, `vertice => {vertice, cost}`


## Todo

- [ ] Move a lot of the "hackityhacks" from `astar_wx.ex` to geo.ex.
- [ ] Align on a single `polygon, point` argument order
- [ ] The polygon "name" thing needs to be addressed - it def must not be in geo.ex
- [ ] vector naming, `start, stop`, `src, dst`
- [ ] Little to no error check of polygon overlap, self-intersection, holes cutting the primary etc.
