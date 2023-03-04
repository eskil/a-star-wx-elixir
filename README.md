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

The graph is a map from `vertice` to a list of `{vertice, cost}`;

An `vertice` is somewhat opaque to the algorithm, it just uses them as
keys.

Two functions are needed by the algorithm.
One `cost_fun, (vertice, vertice) :: cost` to compute the cost
(distance) between two vertices.

One `heur_fun, (vertice, vertice) :: cost` to compute the heuristic cost.

So the first data is a set of vertices.

```elixir
vertices = [{x1, y1}=vertice1, {x2, y2}=vertice2, {x3, y3}=vertice3...]
```

And this is transformed to a graph, where each entry is used as a key
to a list of keys for other vertices. This transformation is not relevant
to the A* algorithm, but the result is the input;

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

An `edge` is a tuple of `{vertice1, vertice2, cost}`.

By using whatever key the vetices list uses, we keep it simple, and
whatever manages the vertices can keep the initial list short, yet
also uses the keys to manage its own affairs.

The A* algorithm thus receives;

* `graph` to search
* `heur_fun` function `vertice, vertice :: cost` computes heuristic cost

The state it maintains

* `queue` priority queue / list `[vertice, vertice, ...]` sorted on an vertices cost.
* `shortest_path_tree`, a map of edges, `vertice => {vertice, cost}`


## Todo

- [ ] Align on a single `polygon, point` argument order
- [ ] The polygon "name" thing needs to be addressed - it def must not be in geo.ex
- [ ] should walkgraph use indexes or points? Ie. `{{vertice_1_idx, vertice_2idx}, weight}` or `{{x1, y1}, {x2, y2}, weight}`?
- [ ] vector naming, `start, stop`, `src, dst`


###

```
class AstarAlgorithm {
	public var graph:Graph;
	public var shortest_path_tree:Array<GraphEdge>;
	public var G_Cost:Array<Float>;	//This array will store the G cost of each node
	public var F_Cost:Array<Float>;	//This array will store the F cost of each node
	public var search_frontier:Array<GraphEdge>;
	public var source:Int;
	public var target:Int;

	public function new(_graph:Graph,_source:Int,_target:Int)
	{
		graph=_graph;
		source=_source;
		target=_target;

		shortest_path_tree= new Array<GraphEdge>();
		G_Cost = new Array<Float>();
		F_Cost = new Array<Float>();
		search_frontier = new Array<GraphEdge>();

		for (i in 0...graph.nodes.length) {
			G_Cost[i] = 0;
			F_Cost[i] = 0;
		}

		search();
	}

	private function search()
	{
		var queue:IndexedPriorityQueue = new IndexedPriorityQueue(F_Cost);
		queue.insert(source);
		while(!queue.isEmpty())
		{
			var next_closest_node:Int = queue.pop();
			shortest_path_tree[next_closest_node] = search_frontier[next_closest_node];
			if (next_closest_node == target) return;
			var edges:Array<GraphEdge>=graph.edges[next_closest_node];
			for (edge in edges)
			{
				var heur_cost:Float = Vector.distance(graph.nodes[edge.to].pos, graph.nodes[target].pos)
				var Gcost:Float = G_Cost[next_closest_node] + edge.cost;
				var Fcost:Float = Gcost+heur_cost;
				var to:Int=edge.to;L
				if (search_frontier[edge.to] == null)
				{
					F_Cost[edge.to]=Fcost
					G_Cost[edge.to]=Gcost;
					queue.insert(edge.to);
					search_frontier[edge.to]=edge;
				}
				else if ((Gcost < G_Cost[edge.to]) && (shortest_path_tree[edge.to] == null))
				{
					F_Cost[edge.to]=Fcost
					G_Cost[edge.to]=Gcost;
					queue.reorderUp();
					search_frontier[edge.to]=edge;
				}
			}
		}
	}

	public function getPath():Array<Int>
	{
		var path:Array<Int> = new Array();
		if(target<0) return path;
		var nd:Int = target;
		path.push(nd);
		while((nd!=source)&&(shortest_path_tree[nd]!=null))
		{
			nd = shortest_path_tree[nd].from;
			path.push(nd);
		}
		path.reverse();
		return path;
	}
}
```
