require "slack-ruby-bot"

module Swimmy
  class App < SlackRubyBot::Server
    on "hello" do |client, data|
      begin
        message = MESSAGE_QUEUE.shift
        ch, post_msg = message.split(':', 2)
        if ch.start_with?("#")
          ch = client.web_client.channels_info(channel: ch).channel.id
        end
        client.say(channel: ch, text: post_msg)
      rescue => e
        puts e
      end
    end

    MESSAGE_QUEUE = []
    def initialize(opt)
      if opt[:spreadsheet]
        Swimmy::Command.spreadsheet =
          initialize_spreadsheet(opt[:spreadsheet])
        opt.delete(:spreadsheet)
      end

      if opt[:mqtt_endpoint]
        Swimmy::Command.mqtt_client =
          initialize_mqtt_client(opt[:mqtt_endpoint])
        opt.delete(:mqtt_endpoint)
      end

      if opt[:hello]
        MESSAGE_QUEUE << opt[:hello]
        opt.delete(:hello)
      end

      super(opt)
    end

    private

    def initialize_spreadsheet(spreadsheet_id)
      require "clian"
      require "sheetq"

      dir = "~/.config/sheetq/"

      config = Sheetq::Config.create_from_file(File.expand_path("config.yml", dir))

      client = Sheetq::GoogleClient.new(
        config.general.client_id,
        config.general.client_secret,
        File.expand_path("token_store.yml", dir),
        config.general.default_user
      )

      client.auth
      return Sheetq::Service::Spreadsheet.new(client, spreadsheet_id)
    end

    def initialize_mqtt_client(broker_endpoint)
      require 'mqtt'

      client = MQTT::Client.connect(broker_endpoint)

      return client
    end

  end # class App
end # module Swimmy

