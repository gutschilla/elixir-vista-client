defmodule VistaClient.Extractors do

  @moduledoc """
  Helper functions to extract and convert certain attributes from a parsed JSOM
  map. For example, IDs are transmitted as strings by VISTA, so we're converting
  them to integers.

  ## Synopsis

        iex> VistaClient.Extractors.extract_id %{"ID" => "1001"}
        {:ok, 1001}

        iex> VistaClient.Extractors.extract_id %{"id" => 1001}
        {:error, :unparsable_id}

  """

  @doc "Extracts the id from a map with an \"ID\" field containing an ID string"
  @type id :: integer()
  @type map_with_id :: %{String.t() => String.t()}
  @spec extract_id(map_with_id, String.t()) :: {:ok, id()} | {:error, :unparsable_id}
  def extract_id(map, id_field \\ "ID") do
    with {:ok, id_string} when is_binary(id_string) <- Map.fetch(map, id_field),
         {id_int, _}                                <- Integer.parse(id_string) do
      {:ok, id_int}
    else
      :error -> {:error, :unparsable_id}
    end
  end

  defp version_priority("OmU"),    do: 3
  defp version_priority("OV"),     do: 2
  defp version_priority("OmUeng"), do: 1
  defp version_priority(_),        do: 0

  defp version_string_for(attributes) do
    attributes
    |> Enum.map(fn v -> {v, version_priority(v)} end)          # add prios
    |> Enum.filter(fn {_v, 0} -> false; _ -> true end)         # remove zero-prios
    |> Enum.max_by(fn {_v, prio} -> prio end, fn -> :none end) # highest prio element
    |> fn {version, _prio} -> version; :none -> "" end.()      # just the version
  end

  @doc """
  Given the \"SessionAttributesNames\" field fron a Session map, takes the list and
  returns a tuple containing the attributes as in there and a version string.

  The version string is the attribute with highest priority in the list of known
  version attributes. Unknown attributes will be discarded.
  """
  @type version :: String.t()
  @type attributes :: list(String.t())
  @type map_with_atttrs :: %{required(String.t()) => attributes}
  @spec extract_attributes(map_with_atttrs) :: {:ok, {version, attributes}} | {:error, :unparsable_session_attributes}
  def extract_attributes(map) do
    with {:ok, attributes} when is_list(attributes) <- Map.fetch(map, "SessionAttributesNames"),
         version_string <- version_string_for(attributes) do
      {:ok, {version_string, attributes}}
    else
      :error -> {:error, :unparsable_id}
    end
  end

  @doc """
  Naive string-to-datetime conversion. Assumes lack of timezone info.

  ## Examples

        iex> #{__MODULE__}.extract_date("2019-02-26T20:00:00")
        {:ok, ~D[2019-02-26]}

  """
  def extract_date(map = %{}, key) when is_binary(key) do
    with {:ok, value} <- Map.fetch(map, key) do
      extract_date(value)
    else
      :error -> {:error, {:key_not_found, key}}
    end
  end
  def extract_date(datetime = %DateTime{}) do
    {:ok, DateTime.to_date(datetime)}
  end
  def extract_date(datetime = %NaiveDateTime{}) do
    {:ok, NaiveDateTime.to_date(datetime)}
  end
  def extract_date(string) when is_binary(string) do
    with {:ok, dt} <- extract_datetime(string),
         result    <- extract_date(dt), do: result
  end

  @doc """
  Naive string-to-datetime conversion. Assumes lack of timezone info.

  ## Examples

        iex> #{__MODULE__}.extract_datetime("2019-02-26T20:00:00")
        {:ok, ~N[2019-02-26 20:00:00]}
  """
  def extract_datetime(map = %{}, key) when is_binary(key) do
    with {:ok, value} <- Map.fetch(map, key) do
      extract_datetime(value)
    else
      :error -> {:error, {:key_not_found, key}}
    end
  end

  def extract_datetime(string) when is_binary(string) do
    with {:ok, dt, _offset} <- DateTime.from_iso8601(string <> "+00:00"),
         naive_dt           <- DateTime.to_naive(dt) do
      {:ok, naive_dt}
    end
  end

end
