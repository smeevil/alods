# At Least Once Deliver System (Alods)

As the name implies, Alods will take core of delivering notifications at
least once. A notification is a simple HTTP GET or POST request being
delivered to a web server. The only valid response that Alods accepts as
a successful delivery is an HTTP Status 200.

If the delivery does not result in an HTTP Status 200 response Alods
will automatically retry it again. The retries will abide by a cool-down
mechanism which will count the retries and and multiply those by 2, the
result of this will be the amount of seconds added to the time of the
last delivery attempt.

An example of retries would be :
- first try, immediately
- second try, 2 seconds after the first try
- third try, 4 seconds after the seconds try
- fourth try, 6 seconds after the third try
- fifth try, 8 seconds after the fourth try
- and so on and so forth

This would mean that the fifth retry would take place 20
seconds after the initial attempt.


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `alods` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:alods, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/alods](https://hexdocs.pm/alods).

## Configuration

```elixir
config :alods,
       start_producers_and_consumers: true, #defaults to true
       consumer_amount: 2, #defaults to 1
       check_for_work_delay: :os.seconds(5), #defaults to 1
       reset_after_processing_in_seconds: 30, #defaults to 60
       store_delivered_entries_for_days: 1 #defaults to 7
```

## Usage


### Notication delivery via GET
To start delivering a notification via the GET method you can use
```elixir
  iex> Alods.notify_by_get("http://example.com/example/path", %{foo: "bar", baz: 1})
  {:ok, "00593e2a-86bd-42cb-bd58-76635e04fbdf"}
```
this will convert the path to
`http://example.com/example/path?foo=bar&baz=1`

### Notication delivery via POST
To start delivering a notification via the POST method you can use
```elixir
  iex> Alods.notify_by_post("http://example.com/example/path", %{foo: "bar", baz: 1})
  {:ok, "00593e2a-86bd-42cb-bd58-76635e04fbdf"}
```
This will make a JSON post to `http://example.com/example/path`
converting the data to JSON automatically.

### Getting a callback on successful delivery
If you would like to receive a callback once the delivery was successful
you can pass a function with an arity of exactly 1 with the calls. Upon
successful delivery this function will be called with a %Alods.Record{}
as argument.

```elixir
  iex> Alods.notify_by_get("http://example.com/example/path", %{foo: "bar", baz: 1, &MyApp.Callback/1})
  {:ok, "00593e2a-86bd-42cb-bd58-76635e04fbdf"}
```

### List Queue
To see what is currently queued for delivery :

```elixir
iex> Alods.Queue.list
[
  %Alods.Record{
      data: %{foo: "bar"},
      id: "4d7ac4a9-2762-4c79-acda-66113d44c2d1",
      reason: %{body: "Unprocessable Entity", status_code: 422},
      method: :get,
      retries: 2,
      status: :pending,
      timestamp: 1506606289,
      url: "http://0.0.0.0/example"
  },
  ...
]
```

## Queue Size
To get the amount of items in the queue

```elixir
iex> Alods.Queue.size()
256
```

## Delivered notifications

You can see all delivered notifications by using:

```elixir
iex> Alods.Delivered.list()
[
  %Alods.Record{
    created_at: #DateTime<2017-10-09 11:25:33.163714Z>,
    data: %{},
    delivered_at: #DateTime<2017-10-09 11:25:33.464013Z>,
    id: "be39835e-50ff-454e-90e2-cdbbd1dc290d",
    method: "get",
    reason: nil,
    retries: 0,
    status: "delivered",
    timestamp: 1507548333,
    updated_at: #DateTime<2017-10-09 11:25:33.464034Z>,
    url: "http://example.com"
   },
   ...
]
```
