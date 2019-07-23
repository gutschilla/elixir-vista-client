defmodule VistaClient.Endpoint do

  defstruct [
    :name,
    :url
  ]

  def from_map(map) do
    with {:n, {:ok, name}} <- {:n, Map.fetch(map, "name")},
         {:u, {:ok, url}}  <- {:u, Map.fetch(map, "url")}
    do
      %__MODULE__{
        name: name,
        url:  url
      }
    else
      {:n, :error}    -> {:error, {:missing_key, "name"}}
      {:u, :error}    -> {:error, {:missing_key, "url"}}
      e = {:error, _} -> e
      other           -> {:error, other}
    end
  end

  def from_map_list(endpoints) do
    Enum.map(endpoints, &from_map/1)
  end
end
