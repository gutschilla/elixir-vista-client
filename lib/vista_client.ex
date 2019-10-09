defmodule VistaClient do

  @behaviour VistaClient.Behaviour

  alias VistaClient.{Config, SessionAvailability, Session, Cinema, Film, Endpoint}

  @moduledoc ~s"""
  Documentation for VistaClient.

  ## Examples

      iex> {:ok, cinemas} = VistaClient.get_cinemas()
      iex> cinemas |> Enum.find(fn cinema -> cinema.id == 1001 end)
      %VistaClient.Cinema{id: 1001, name: "Delphi Lux"}
  """

  @type reason :: any()
  @type headers :: list({charlist(), charlist()})

  @doc "creates auth and content-type and accept headers"
  @spec make_basic_headers() :: {:ok, headers} | {:error, reason}
  def make_basic_headers do
    with %Config{api_token: api_token} <- Config.get() do
      {:ok, [
          {"connectapitoken", api_token},
          {"Content-Type", "application/json"}
        ]
      }
    else
      %Config{} -> {:error, :api_token_missing_in_config}
      _         -> {:error, :config_not_available}
    end
  end

  @type retrieved_entity :: :cinemas | :scheduled_films | :sessions
  @type url :: charlist()

  @spec url_for(retrieved_entity, keyword()) :: {:ok, url} | {:error, reason}
  def url_for(what, opts \\ []) do
    with %Config{api_url: api_url} <- Config.get(),
         {:p, params}              <- {:p, Keyword.get(opts, :params, [])},
         {:ok, url}                <- make_url_for(what, api_url, params) do
      {:ok, url}
    else
      %Config{}        -> {:error, :api_url_missing_in_config}
      {:error, reason} -> {:error, reason}
    end
  end

  def make_url_for(:root, api_url) do
    {:ok, api_url <> "OData.svc"}
  end

  def make_url_for(:cinemas, api_url) do
    {:ok, api_url <> "OData.svc/Cinemas"}
  end

  def make_url_for(:scheduled_films, api_url) do
    # https://cine-web.yorck.de:42282/WSVistaWebClient/Odata.svc/GetScheduledFilms?cinemaid=1014&$format=json&$orderby=Title&$expand=Sessions
    {:ok, api_url <> "OData.svc/GetScheduledFilms"}
  end

  def make_url_for(:sessions, api_url) do
    {:ok, api_url <> "OData.svc/Sessions"}
  end

  def make_url_for(:seats_available, api_url, [session_id: id_string]) when is_binary id_string do
    {:ok, api_url <>  "OData.svc/Sessions?$select=ID,SeatsAvailable&$filter=ID+eq+'#{id_string}'"}
  end

  def make_url_for(:validate_member, api_url) do
    {:ok, api_url <> "RESTLoyalty.svc/member/validate"}
  end

  # convert make_url_for/3 to make_url_for/2
  def make_url_for(what, api_url, []) do
    make_url_for(what, api_url)
  end

  @type retrieved_endpoint :: :validate_member
  @type param_list :: list()
  @type payload :: String.t()
  @spec payload_for(retrieved_endpoint, param_list) :: {:ok, payload} | {:error, reason}

  def payload_for(retrieved_endpoint, param_list) do
    {:ok, payload} = make_payload_for(retrieved_endpoint, param_list)
  end

  def make_payload_for(:validate_member, param_list) do
    Jason.encode(param_list)
  end

  def make_request(url) do
    with {:ok, headers}                      <- make_basic_headers(),
         {:ok, status, _headers, client_ref} <- :hackney.request(:GET, url, headers),
         {:ok, body}                         <- :hackney.body(client_ref),
         {:status, 200, body}                <- {:status, status, body} do
      {:ok, body}
    else
      {:error, reason}     -> {:error, reason}
      {:status, 500, body} -> {:error, {:server_error, body}}
      reason               -> {:error, {:something_went_wrong, reason}}
    end
  end

  def post_request(url, payload) do
    with {:ok, headers}                      <- make_basic_headers(),
         {:ok, status, _headers, client_ref} <- :hackney.request(:POST, url, headers, payload),
         {:ok, body}                         <- :hackney.body(client_ref),
         {:status, 200, body}                <- {:status, status, body} do
      {:ok, body}
    else
      {:error, reason}     -> {:error, reason}
      {:status, 500, body} -> {:error, {:server_error, body}}
      reason               -> {:error, reason}
    end
  end

  def make_structs(endpoints, :root),            do: Endpoint.from_map_list(endpoints)
  def make_structs(endpoints, :endpoints),       do: Endpoint.from_map_list(endpoints)
  def make_structs(films,     :scheduled_films), do: Film.from_map_list(films)
  def make_structs(sessions,  :sessions),        do: Session.from_map_list(sessions)
  def make_structs(cinemas,   :cinemas),         do: Cinema.from_map_list(cinemas)
  def make_structs(seats,     :seats_available), do: SessionAvailability.from_map_list(seats)

  def get(what, opts \\ []) do
    with {:ok, url}       <- url_for(what, opts),
         {:ok, json_body} <- make_request(url),
         {:ok, map}       <- Jason.decode(json_body),
         {:ok, value}     <- Map.fetch(map, "value") do
      case Keyword.get(opts, :output) do
        nil       -> make_structs(value, what)
        :raw_maps -> {:ok, value}
      end
    else
      {:error, reason} -> {:error, reason}
      reason           -> {:error, reason}
    end
  end

  def post(where, param_list, opts \\ []) do
    with {:ok, url}         <- url_for(where, opts),
         {:ok, payload}     <- payload_for(where, param_list),
         {:ok, json_body}   <- post_request(url, payload),
         {:ok, result_body} <- Jason.decode(json_body) do
      {:ok, result_body}
    else
      {:error, reason} -> {:error, reason}
      reason           -> {:error, reason}
    end
  end

  def get_cinemas,         do: get(:cinemas)
  def get_scheduled_films, do: get(:scheduled_films)
  def get_sessions,        do: get(:sessions)
  def get_endpoints,       do: get(:root)

  def get_session_availabilty(session_id) do
    case get(:seats_available, params: [session_id: session_id]) do
      {:ok, [s = %SessionAvailability{}]} -> {:ok, s}
      {:ok, []}                           -> {:error, {:session_not_found, session_id}}
      {:error, reason}                    -> {:error, reason}
    end
  end

  @doc """
  Returns
  - {:ok, true} if VISTA server seems up
  - {:ok, false} if not
  - {:error, reason} on config error

  ## EXAMPLES
      iex> VistaClient.online?()
      {:ok, true}
  """
  @spec online? :: {:ok, boolean()} | {:error, reason}
  def online? do
    with {:ok, url}                       <- url_for(:root),
         {:ok, headers}                   <- make_basic_headers(),
         {:ok, 200, _headers, client_ref} <- :hackney.request(:GET, url, headers) do
      {:ok, true}
    else
      {:error, reason} -> {:error, reason}
      _                -> false
    end
  end
end
