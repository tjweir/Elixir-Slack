defmodule Slack do
  @moduledoc """
  A behavior for the Slack real time messaging API via websockets.

  ## Example

  ```
  defmodule SlackRtm do
    use Slack

    def start_link() do
      Slack.start_link(__MODULE__, "token_value")
    end

    def init(_socket) do
      {:ok, []}
    end

    def handle_message({:type, "message", response}, socket, state) do
      Slack.send_message("Received message!", response.channel, socket)
      state = state ++ [response.text]
      {:ok, state}
    end

    def handle_message({:type, type, _response}, _socket, state) do
      IO.puts "No callback for #\{type}"
      {:ok, state}
    end
  end
  ```

  Slack has a large variety of types it can send you, so it's wise ot have a
  catch all handle like above to avoid crashing.

  You can find every type Slack will respond with and examples of each on
  the [Slack RTM API](https://api.slack.com/rtm) page.
  """
  use Behaviour

  defmacro __using__(_) do
    quote do
      @behaviour Slack

      def init(_) do
        {:ok, nil}
      end

      def handle_message({:type, type, _response}, _socket, state) do
        {:stop, {:unhandled_type, type}, state}
      end

      defoverridable [init: 1, handle_message: 3]
    end
  end

  defcallback init(:websocket_req.Req) :: {:ok, any}
  defcallback handle_message(
    {:type, binary, map},
    :websocket_req.Req,
    any
  ) :: {:ok, any}

  @doc """
  Starts a websocket connection to the Slack real time messaging API using the
  given token.

  Once started it calls the `init/1` function on the given module passing in the
  websocket connection as its argument.
  """
  def start_link(module, token, rtm \\ Slack.Rtm, websocket \\ :websocket_client) do
    {:ok, rtm_response} = rtm.start(token)
    url = rtm_response.url |> String.to_char_list

    websocket.start_link url, Slack.Socket, module
  end

  @doc """
  Sends `text` as a message to the the channel with id of `channel_id`

  eg: `Slack.send_message("Morning everyone!", "CA1B2C3D4", sock)`
  """
  def send_message(text, channel_id, socket, websocket \\ :websocket_client) do
    message = %{type: "message", text: text, channel: channel_id}
              |> JSX.encode!

    websocket.send({:text, message}, socket)
  end
end
