defmodule VistaClient.SessionAvailability do

  @derive Jason.Encoder

  defstruct [
    seats_available: 0,
  ]

  @doc """
  Serves as typed integer for seat availability. (Sometimes, Haskell-style types
  would be cool).
  """

  def from_map(map) do
    with {:v, {:ok, seats_available}} <- {:v, Map.fetch(map, "SeatsAvailable")} do
      %__MODULE__{seats_available: seats_available}
    else
      {:v, :error} -> {:error, {:missing_key, "SeatsAvailable"}}
      other -> {:error, other}
    end
  end

  def handle_validity(structs, filtered, _) when structs == filtered, do: {:ok, structs}
  def handle_validity(s, f, [ignore_errors: true])  when s == f, do: {:ok, f}
  def handle_validity(s, f, [ignore_errors: false]) when s != f, do: {:error, :unparsable_seat_availability}

  def from_map_list(films, opts \\ [ignore_errors: false]) do
    with structs        <- Enum.map(films, &from_map/1),
         filtered       <- Enum.filter(structs, fn %__MODULE__{} -> true; _ -> false end),
         {:ok, structs} <- handle_validity(structs, filtered, opts), do: {:ok, structs}
  end

end
