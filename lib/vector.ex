defmodule Vector do
  @moduledoc """
  Functions to work on vectors.

  Vectors are represented as tuples of x and y coordinates, `{x, y}`. This
  module provides basic trigonometry functions.

  """

  @doc"""
  Get the length of a vector.
  """
  def len({x, y}) do
    :math.sqrt(x * x + y * y)
  end

  @doc"""
  Add two vectors together.
  """
  def add({ax, ay}, {bx, by}) do
    {ax + bx, ay + by}
  end

  @doc"""
  Subtract a vector from another.
  """
  def sub({ax, ay}, {bx, by}) do
    {ax - bx, ay - by}
  end

  @doc"""
  Divide a vector by a constant.

  ## Examples
    iex> Vector.div({10, 10}, 2)
    {5.0, 5.0}
  """
  def div({x, y}, c) do
    {x / c, y / c}
  end

  @doc"""
  Multiply a vector by a constant.
  """
  def mul({x, y}, c) do
    {x * c, y * c}
  end

  @doc"""
  Get the distance of two vectors.
  """
  def distance({_ax, _ay}=a, {_bx, _by}=b) do
    len(sub(b, a))
  end

  @doc"""
  Get the distance squared of two vectors.
  """
  def distance_squared({ax, ay}, {bx, by}) do
    :math.pow(ax - bx, 2) + :math.pow(ay - by, 2)
  end

  @doc"""
  Normalise (len=1) a vector.
  """
  def normalise({x, y}=v) do
    l = len(v)
    {x / l, y / l}
  end

  @doc"""
  Get the dot product of two vectors.
  """
  def dot({ax, ay}, {bx, by}) do
    ax * bx + ay * by
  end

  @doc"""
  Get the cross product of two vectors.
  """
  def cross({ax, ay}, {bx, by}) do
    ax * by - ay * bx
  end

  @doc"""
  Shorten a vector by a certain amount of "points".
  """
  def shorten({x, y}=v, sz) do
    s = 1 - sz/len(v)
    {x * s, y * s}
  end

  @doc"""
  Get the magnitude of a vector
  """
  def mag({x, y}) do
    :math.sqrt(:math.pow(x, 2) + :math.pow(y, 2))
  end

  @doc """
  Get the angle of a vector.
  """
  def angle({0.0, y}) when y < 0 do
    - :math.pi / 2
  end

  def angle({0.0, _y}) do
    :math.pi / 2
  end

  def angle({0, y}) when y < 0 do
    - :math.pi / 2
  end

  def angle({0, _y}) do
    :math.pi / 2
  end

  def angle({x, y}) do
    :math.atan(-y / -x)
  end

  @doc"""
  Calls trunc on a vector to make the vector work with wx (requires integers).
  """
  def trunc_pos({x, y}) do
    {trunc(x), trunc(y)}
  end

  @doc"""
  Calls round on a vector to make the vector work with wx (requires integers).
  """
  def round_pos({x, y}) do
    {round(x), round(y)}
  end

  @doc """
  This is a graph oriented degree, ie. right is 0, up is 90 etc.

  ## Examples
      iex> alias Vector, as: Vector
      Vector
      iex> Vector.degrees_a({1, 1})
      45.0
      iex> Vector.degrees_a({0, 1})
      90.0
      iex> Vector.degrees_a({1, 0})
      -0.0
      iex> Vector.degrees_a({-1, 1})
      135.0
      iex> Vector.degrees_a({-1, 0})
      180.0
      iex> Vector.degrees_a({-1, -1})
      225.0
      iex> Vector.degrees_a({0, -1})
      270.0
      iex> Vector.degrees_a({1, -1})
      315.0
  """
  def degrees_a({x, y}=v) do
    a = angle(v) * (180 / :math.pi)
    a = if x < 0 do
      180 + a
    else
      if y < 0 do
        360 + a
      else
        a
      end
    end
    a
  end

  @doc """
  This is a screen oriented degree. Degrees are in North=up (0) South=down (180) degrees.
  Vectors are in x,y screen coordinate, so 1,1 = 135D down to right

  ## Examples
      iex> Vector.degrees({0, -1})
      0
      iex> Vector.degrees({1, -1})
      45
      iex> Vector.degrees({1, 0})
      90
      iex> Vector.degrees({1, 1})
      135
      iex> Vector.degrees({0, 1})
      180
      iex> Vector.degrees({-1, 1})
      225
      iex> Vector.degrees({-1, 0})
      270
      iex> Vector.degrees({-1, -1})
      315
  """
  def degrees({x, _y}=v) do
    # z is our "north" and it's pointing "right" to rotate.
    z = {0, -1}
    d = dot(v, z)
    cos_a = d / (mag(v) * mag(z))
    d = :math.acos(cos_a) * (180 / :math.pi)
    if x < 0 do
      360 - d
    else
      d
    end
    |> round
  end
end
