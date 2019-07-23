defmodule VistaClient.Session do

  @derive Jason.Encoder

  @moduledoc """
  Struct to represent an Session.

  # Definition _Sessions_

  A scrrening show of a film in a cinema on a
  screen at a certain time. This is what people book tickets for.

  # JSON example:

  ```
  {
    "ID": "1001-14164",
    "CinemaId": "1001",
    "ScheduledFilmId": "HO00000720",
    "SessionId": "14164",
    "AreaCategoryCodes": [],
    "Showtime": "2019-02-26T20:00:00",
    "IsAllocatedSeating": false,
    "AllowChildAdmits": true,
    "SeatsAvailable": 66,
    "AllowComplimentaryTickets": true,
    "EventId": "",
    "PriceGroupCode": "0033",
    "ScreenName": "Kino 2",
    "ScreenNameAlt": "433402",
    "ScreenNumber": 2,
    "CinemaOperatorCode": "1001",
    "FormatCode": "0000000001",
    "FormatHOPK": "0000000001",
    "SalesChannels": ";CALL;RSP;GSALE;CELL;KIOSK;PDA;WWW;POSBK;POS;IVR;",
    "SessionAttributesNames": ["OV"],
    "ConceptAttributesNames": [],
    "AllowTicketSales": true,
    "HasDynamicallyPricedTicketsAvailable": false,
    "PlayThroughId": null,
    "SessionBusinessDate": "2019-02-26T00:00:00",
    "SessionDisplayPriority": 0,
    "GroupSessionsByAttribute": false,
    "SoldoutStatus": 0,
    "TypeCode": "N"
  }
  ```
  """
  defstruct [
    :id_string,
    :film_id_string,
    :film,
    :screen_name,
    :seats_available,
    :cinema_id,
    :cinema,
    :attributes,
    :version,
    :showtime, # <-- when the movie starts
    :date      # <-- for which day this counts (screening at 1AM counts for day before, usually)
  ]

  import VistaClient.Extractors, only: [
    {:extract_id, 2},
    {:extract_attributes, 1},
    {:extract_datetime, 2},
    {:extract_date, 2}
  ]

  def from_map(map) do
    with {:f, {:ok, film_id_string}}    <- {:f, Map.fetch(map, "ScheduledFilmId")},
         {:s, {:ok, session_id_string}} <- {:s, Map.fetch(map, "ID")},
         {:n, {:ok, screen_name}}       <- {:n, Map.fetch(map, "ScreenName")},
         {:a, {:ok, seats_available}}   <- {:a, Map.fetch(map, "SeatsAvailable")},
         {:ok, cinema_id}               <- extract_id(map, "CinemaId"),
         {:ok, showtime}                <- extract_datetime(map, "Showtime"),
         {:ok, date}                    <- extract_date(map, "SessionBusinessDate"),
         {:ok, {version, attributes}}   <- extract_attributes(map) do
      %__MODULE__{
        id_string:       session_id_string,
        screen_name:     screen_name,
        seats_available: seats_available,
        film_id_string:  film_id_string,
        cinema_id:       cinema_id,
        attributes:      attributes,
        version:         version,
        showtime:        showtime,
        date:            date
      }
    else
      {:f, _} -> {:error, {:missing_key, "ScheduledFilmId"}}
      {:s, _} -> {:error, {:missing_key, "ID"}}
      {:n, _} -> {:error, {:missing_key, "ScreenName"}}
      {:a, _} -> {:error, {:missing_key, "ScreenName"}}
      error -> error
    end
  end

  def handle_validity(structs, filtered, _) when structs == filtered, do: {:ok, structs}
  def handle_validity(s, f, [ignore_errors: true])  when s == f, do: {:ok, f}
  def handle_validity(s, f, [ignore_errors: false]) when s != f, do: {:error, :contains_unparsable_session}

  def from_map_list(sessions, opts \\ [ignore_errors: false]) do
    with structs        <- Enum.map(sessions, &from_map/1),
         filtered       <- Enum.filter(structs, fn %__MODULE__{} -> true; _ -> false end),
         {:ok, structs} <- handle_validity(structs, filtered, opts), do: {:ok, structs}
  end

  # HELPERS

  @doc """
  Takes a session and returns the seconds until the screening starts.

  - Can be negative (session already started or has run
  - Depends on erlang.localtime to be correct

  #FIXME: Abandon Naive DateTime

  Let's abandon localtimes and naive datettimes and just use UTC passing
  DateTime structs around.
  """
  @spec showing_in(%__MODULE__{}) :: integer()
  def showing_in(%__MODULE__{showtime: showtime}) do
    # we really hould abandon naive datetimes
    {{year, month, day}, {hour, minute, second}} = :erlang.localtime()
    now_dt = %DateTime{
      calendar: Calendar.ISO,
      day: day,
      hour: hour,
      microsecond: {0, 6},
      minute: minute,
      month: month,
      second: second,
      std_offset: 0,
      time_zone: "Etc/UTC",
      utc_offset: 0,
      year: year,
      zone_abbr: "UTC"
    }
    show_dt = DateTime.from_naive!(showtime, "Etc/UTC")
    DateTime.diff(show_dt, now_dt)
  end

end
