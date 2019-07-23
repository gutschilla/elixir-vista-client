defmodule VistaClient.Cinema do

  import VistaClient.Extractors, only: [{:extract_id, 2}]

  defstruct [
    :id,
    :name
  ]

  def from_map(map) do
    with {:n, {:ok, name}} <- {:n, Map.fetch(map, "Name")},
         {:ok, id}         <- extract_id(map, "ID")
      do
      %__MODULE__{
        name: name,
        id: id
      }
      else
        {:n, :error}    -> {:error, {:missing_key, "name"}}
        e = {:error, _} -> e
        other           -> {:error, other}
    end
  end

  def handle_validity(structs, filtered, _) when structs == filtered, do: {:ok, structs}
  def handle_validity(s, f, [ignore_errors: true])  when s == f, do: {:ok, f}
  def handle_validity(s, f, [ignore_errors: false]) when s != f, do: {:error, :contains_unparsable_cinema}

  def from_map_list(cinemas, opts \\ [ignore_errors: false]) do
    with structs        <- Enum.map(cinemas, &from_map/1),
         filtered       <- Enum.filter(structs, fn %__MODULE__{} -> true; _ -> false end),
         {:ok, structs} <- handle_validity(structs, filtered, opts), do: {:ok, structs}
  end

end

defimpl Jason.Encoder, for: VistaClient.Cinema do
  def encode(%VistaClient.Cinema{id: id, name: name}, opts) do
    map = %{
      "id"     => id,
      "name"   => name,
    }
    Jason.Encode.map(map, opts)
  end
end
