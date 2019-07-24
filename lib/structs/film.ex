defmodule VistaClient.Film do
  defstruct [
    id:       nil,
    name:     nil,
    rating:   nil
  ]

  @doc """
  Gets real film names from sortable names with trailing pronouns. Works with
  German and English pronouns.

  ## Examples

        iex> VistaClient.Film.transform_name("great Escape, The")
        "The great Escape"

        iex> VistaClient.Film.transform_name("große Flucht, Die")
        "Die große Flucht"
  """
  def transform_name(name_string) do
    reg = ~r/(.*),\s*(the|der|die|das)\s*\z/i
    String.replace(name_string, reg, "\\2 \\1")
  end

  def transform_rating("FSK unbek."), do: :unknown
  def transform_rating(rating),       do: {:rating, rating}

  def from_map(map) do
    with {:i, {:ok, id_string}}     <- {:i, Map.fetch(map, "ScheduledFilmId")},
         {:n, {:ok, name_string}}   <- {:n, Map.fetch(map, "Title")},
         {:r, {:ok, rating_string}} <- {:r, Map.fetch(map, "Rating")},
         name                       <- transform_name(name_string),
         rating                     <- transform_rating(rating_string) do
      %__MODULE__{
        id:     id_string,
        name:   name,
        rating: rating
      }
    else
      {:i, :error} -> {:error, {:missing_key, "ScheduledFilmId"}}
      {:n, :error} -> {:error, {:missing_key, "Title"}}
      {:r, :error} -> {:error, {:missing_key, "Rating"}}
      error = {:error, _} -> error
      other -> {:error, other}
    end
  end

  def handle_validity(structs, filtered, _) when structs == filtered, do: {:ok, structs}
  def handle_validity(s, f, [ignore_errors: true])  when s == f, do: {:ok, f}
  def handle_validity(s, f, [ignore_errors: false]) when s != f, do: {:error, :contains_unparsable_film}

  def from_map_list(films, opts \\ [ignore_errors: false]) do
    with structs        <- Enum.map(films, &from_map/1),
         filtered       <- Enum.filter(structs, fn %__MODULE__{} -> true; _ -> false end),
         {:ok, structs} <- handle_validity(structs, filtered, opts), do: {:ok, structs}
  end

end

defimpl Jason.Encoder, for: VistaClient.Film do
  def encode(%VistaClient.Film{id: id, name: name, rating: rating}, opts) do
    map = %{
      "id"     => id,
      "name"   => name,
      "rating" => fn (:unknown) -> "unknown"; {:rating, r} -> r end.(rating)
    }
    Jason.Encode.map(map, opts)
  end
end
