# VistaClient

A client to read cinema program data from VistaConnect. Example data is provide
for Yorck Cinemas Berlin.

# Synopsis

retrieve cinemas an their IDs

```elixir
iex> VistaClient.get_cinemas()
{:ok,
 [
   %VistaClient.Cinema{id: 1001, name: "Delphi Lux"},
   %VistaClient.Cinema{id: 1002, name: "Babylon"},
   %VistaClient.Cinema{id: 1003, name: "Rollberg"},
   %VistaClient.Cinema{id: 1004, name: "Yorck"},
   ...
 ]}
```

get movies that are scheduled to play (from now on)
```
iex(2)> VistaClient.get_scheduled_films
{:ok,
 [
   %VistaClient.Film{
     id: "HO00001047",
     name: "Die Drei !!!",
     rating: {:rating, "FSK 0"}
   },
   %VistaClient.Film{
     id: "HO00000961",
     name: "Leid und Herrlichkeit",
     rating: {:rating, "FSK 6"}
   },
   ...
]}
```

get scheduled sessions
```elixir
iex(3)> VistaClient.get_sessions
{:ok,
 [
   %VistaClient.Session{
     attributes: ["OV"],
     cinema: nil,
     cinema_id: 1001,
     date: ~D[2019-08-08],
     film: nil,
     film_id_string: "HO00000866",
     id_string: "1001-19837",
     screen_name: "Kino 2",
     seats_available: 125,
     showtime: ~N[2019-08-08 20:00:00],
     version: "OV"
   },
   %VistaClient.Session{
     attributes: [],
     cinema: nil,
     cinema_id: 1001,
     date: ~D[2019-07-23],
     film: nil,
     film_id_string: "HO00000908",
     id_string: "1001-20302",
     screen_name: "Kino 4",
     seats_available: 53,
     showtime: ~N[2019-07-23 20:15:00],
     version: ""
   },
   ...
  ]}
```

get individual session seat availabilty

```elixir
iex> VistaClient.get_session_availabilty("1001-20329")  
{:ok, %VistaClient.SessionAvailability{seats_available: 119}}
```

## Structs and JSON

This package will return `VistaClient.Film`, `.SessionAvailability` and
`.Session` and `.Cinema` structs for easy matching in your Elixir programs.

They all implement `Jason.Encoder`, so you can easily feed them to `Jason.encode`.

## Filters

There are a few andy filters defined in
`VistaClient.Transformations.Filters.Sessions` and `.Films` and subsequently
`.FilmsSessions`. You can easily get all sessions and then all films and the get
a pretty list of what's going on today like this:

```elixir
{:ok, films} = VistaClient.get_scheduled_films()
{:ok, sessions} = VistaClient.get_sessions()
VistaClient.Transformations.get_films_sessions_for_day({sessions, films}, 1001, ~D"2019-07-23")
[
  { 
   %VistaClient.Film{id: "HO00000980", name: "Apocalypse Now - The Final Cut (2019)", rating: {:rating, "FSK 16"}},
   [
     %VistaClient.Session{..,  screen_name: "Kino 1", seats_available: 115, showtime: ~N[2019-07-23 20:40:00], version: "OmU"},
     %VistaClient.Session{..,  screen_name: "Kino 2", seats_available: 245, showtime: ~N[2019-07-23 22:00:00], version: ""}
   ]},
  {
  %VistaClient.Film{id: "HO00000908", name: "Burning", rating: {:rating, "FSK 16"}},
   [
     %VistaClient.Session{..., showtime: ~N[2019-07-23 20:15:00]},
   ]
   }
]
```

The above means that there are two films playing on the 23rd of July 2019:
"Apocalypse Now" with two screenings at 20:40 and 22:00 and "Burning" with one
screening at 20:15. Extra fields were omitted for brevity.

Keep in mind, this returns a list of `{film, list_of_sessions}` -tuples. If you
want to have them serialized to JSON, use
`VistaClient.Transformations.Serializer.from_day_result/1`

## Documentation

More documentation on filters, transformations and serializers can be found on
HexDocs for this module.

## Installation

The package can be installed by adding `vista_client` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vista_client, "~> 0.1.0"}
  ]
end
```

## Configuration

Either set environment variables `VISTA_API_TOKEN` (must be string) and
`VISTA_API_URL` (must be a URL starting with "https://") in your runtime
envoronment or configure the `:vista_client` app in your project.

in your `config/config.exs` or `config/<dev|prod|test>.exs`
```elixir
config :vista_client, 
  vista_api_key: "uwagaherebedransonsJGGFU%$", # <- use your api key
  vista_api_url: "https://vista-connect.big-cinema-chain.com:42182/WSVistaWebClient/" # <- use your URL
```
