# AstarWx

A graphical demo of
[A-star 2d polygon map search](https://en.wikipedia.org/wiki/A*_search_algorithm)
in Elixir using WxWidgets.

The "world" is made up of a primary polygon. It has holes defined by
smaller polygons inside it. These are impassable. A-star finds the shortest path around these.

![animated gif showing demo](/images/a-star-sample.gif?raw=true "A-star demo")

A common use case for this is in games where actors have to move around a screen/map.

This is a standalone example with all the relevant code in `lib/`.

## How to run

Assuming you have
[elixir installed](https://elixir-lang.org/install.html) (written with
1.14). Build and run;

```
mix deps.get
mix compile
mix run --no-halt
```

## How to use

* The start point is a *green crosshair*.
* The cursor position is a *red crosshair* if inside the main polution, *gray* if outside.
* Moving the mouse will show a line from start to the cursor.
  * It'll be *green* if the there's a line of sight.
  * It'll be *gray* if not, and there'll be a *small red crosshair* at
    the first blockage, and *small gray crosshair* all subsequent
    blocks.
* Holding down left mouse button will show full search graph in
  *bright orange* and a *thick green path* for the found path.
* Releasing the left mouse button resets the start to there.
  * You can place the start outside the main polygon.

## Internals

There's better API documentation availabe by checking out the repo, making the docs and reading those.

```
mix docs
open doc/index.html
```

See the [quickstart](doc/Quickstart.md).

### Vectors

In `lib/vector.ex` you'll find the basic vector operations (dot,
cross, length, add/sub) needed.

A vector is a tuple of positions, `{x, y}`.

### Lines

A line is a tuple of vectors, `{{x1, y1}, {x2, y2}}`.

### Polygon

In `lib/plygon.ex` you'll find the various polygon related functions,
such as line of sight, nearest point, convex etc.

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
      [x, y], [x, y], [x,y], ...
    ],
    "hole1": [
      [x, y], [x, y], [x,y], ...
    ],
    "hole2": [
      [x, y], [x, y], [x,y], ...
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

The polygon name is only used when detecting if the destination for
pathfinding is within a hole. The name is just printed. Besides that
they're not used and mostly discarded.

### Graph

The graph is a map from `vertice` to a list of `{vertice, cost}`. This
is computed from the polygon map using a set of vertice. This set is
composed of;

* the main polygon's *concave*  (pointing into the world)
* the holes' *convex* (point out of the hole, into the world)


```elixir
vertices = [{x1, y1}=vertice1, {x2, y2}=vertice2, {x3, y3}=vertice3...]
```

This is transformed to a graph, where each entry is used as a key to a
list of keys to other vertices and their cost. This transformation is
not strictly relevant to the A-star algorithm, but the result is the
input.

Assuming a `cost_fun` that has type `vertice, vertice :: cost`, the graph looks like;

```elixir
graph = %{
  vertice1 => [
    vertice2, cost_fun(vertice1, vertice2),
    vertice3, cost_fun(vertice1, vertice3),
    vertice4, cost_fun(vertice1, vertice4),
  ],
  # When expressed as "vertice = {x, y}"
  {x1, x2} => [
    {{x2, y2}, cost_fun({x1, y2}, {x2, y2})},
    {{x3, y3}, cost_fun({x1, y2}, {x3, y3})},
    ...
  ],
  ...
}
```

The default `cost_fun` and `heur_fun` is the euclidean distance been
the two points.

```elixir
cost_fun = fn a, b -> Vector.distance(a, b) end
```

An `edge` is a tuple of `{vertice1, vertice2, cost}`.


### A-star

In the context of A-star, we use `node` instead of `vertice` since we're
describing graphs - not strictly polygons. In the example, each node
is a polygon vertice (ie. `{x, y}`).

A `node` is somewhat opaque to the algorithm, it just uses them as
keys and arguments to `heur_fun`. This was written with `node` being
`{x, y}` tuples (polygon nodex/vector vertexes), but they could also be
indexes.

By using whatever key the vetices list uses, we keep it simple, and
whatever manages the nodes can keep the initial list short, yet
also uses the keys to manage its own affairs.

The A-star algorithm thus receives;

* `graph` to search. The graph should be constructed as

```elixir
graph = %{
  node1 => [
    node2, cost_fun(node1, node2),
    node3, cost_fun(node1, node3),
    node4, cost_fun(node1, node4),
  ],
  # When expressed as "node = {x, y}"
  {x1, x2} => [
    {{x2, y2}, cost_fun({x1, y2}, {x2, y2})},
    {{x3, y3}, cost_fun({x1, y2}, {x3, y3})},
    ...
  ],
  ...
}
```

* `start` and `stop`, the nodes to find a path between.

* `heur_fun` function `node, node :: cost` computes the heuristic
  cost. The default is the euclidian distance.

```elixir
fn a, b -> Vector.distance(a, b) end
```

The state it maintains

* `queue` priority queue / list `[node, node, ...]` sorted on
  the cost (see `f_cost` below) of the path from `start` to node to
  `stop`.

* `shortest_path_tree`, a map of edges, `node_a => node_b`,
  where `node_b` is the "previous" node from `node_a` that is
  the shortest path.

* `frontier` map of `node => node (prev)` that have been reached
  and edges yet to try and have been added to the `queue`. It's a map,
  so when we visit a node, we can add how we reached it to
  `shortest_path_tree`.

* `g_cost`, map `node => cost` with the minimal current cost from
  the `start` to `node`. Each iteration compare the current
  node's `g_cost` against the value in the map. If it's less, we've
  found a shorter path to this node and update the `g_cost` map.

* `f_cost`, map `node => cost` with the "total cost" of path from
  `start`, via node, to `stop`. This means the computed minimal
  cost from `start` to node (`g_cost`) plus the heuristic cost via
  `heur_fun`. This is used to reorder `queue`.

Within `astar.ex`, there's two steps; search & getting the
path. `search` returns the full state, and `path` could be
extended to return the cost along the path if needed. It can fetch
this from `g_cost.`

## Todo

- [ ] vector naming, `start, stop`, `src, dst`
- [ ] Little to no error check of polygon overlap, self-intersection, holes cutting the primary etc.

## Resources

This was put together using a lot of online resources and resources they link to.

* [Grobelsloot](https://github.com/MicUurloon/AdventurePathfinding/tree/master) a-* in haxe.
* [Visionaire](https://wiki.visionaire-tracker.net/wiki/Scenes_and_Objects) description and images
* [David G](https://www.david-gouveia.com/pathfinding-on-a-2d-polygonal-map) Pathfinding on a 2D Polygonal Map
* [Clipper](https://sourceforge.net/p/polyclipping/code/HEAD/tree/trunk/cpp/clipper.hpp) C++ geometry library
* [Kyryl K](https://khorbushko.github.io/article/2021/07/15/the-area-polygon-or-how-to-detect-line-segments-intersection.html) The smart polygon or how to detect line segments intersection
* [SO How do you detect where two line segments intersect?](https://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect) SO that explains "ua=0" and "ub=1"...
