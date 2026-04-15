# coding: utf-8
# This is a part of https://github.com/nomlab/swimmy

require 'json'
require 'uri'
require 'net/https'
require 'pp'
require 'date'
require 'fileutils'
require 'active_support/time'

module Swimmy
  module Command
    class Today < Base
      command "today" do |client, data, match|
        client.say(channel: data.channel, text: "予定を取得中...")

        google_oauth ||= begin
          Swimmy::Resource::GoogleOAuth.new('config/credentials.json', 'config/tokens.json')
        rescue
          message = 'Google OAuthの認証に失敗しました．適切な認証情報が設定されているか確認してください．'
          client.say(channel: data.channel, text: message)
          return
        end

        # begin
          message = "今日 (#{Date.today.strftime('%Y-%m-%d')}) の予定\n"
          message << GetEvents.new(spreadsheet, google_oauth).message
        # rescue
        #   message = "予定の取得に失敗しました．"
        # end

        client.say(channel: data.channel, text: message)
      end # command message

      help do
        title "today"
        desc "今日の予定を表示します．"
        long_desc "今日の予定を表示します．引数はいりません．"
      end # help message
    end # class Today


    class GetEvents
      require 'sheetq'

      def initialize(spreadsheet, google_oauth)
        @sheet = spreadsheet.sheet("calendar", Swimmy::Resource::Calendar)
        @google_oauth = google_oauth
      end

      def message
        calendars = @sheet.fetch
        events = []
        message = ""
        calendars.each do |calendar|
          events.concat(get_event(calendar.id, calendar.name))
        end

        events = events.sort_by{|x| [x[0], x[1]]}
        message = "- 今日の予定はありません．\n" if events.empty?

        for time, summary, name in events
          if time =~ /(\d{2}):(\d{2}):(\d{2})/
            time = $1 + ":" + $2
          end
          message << "#{time} #{summary} (#{name})\n"
        end

        return message
      end

      private

      def get_event(calendar_id, calendar_name)
        events = []
        raw_events = hit_goolge_calendar_api(calendar_id, @google_oauth.token)
        events = format_events_from_json(raw_events, calendar_name)

        return events
      end

      def hit_goolge_calendar_api(calendar_id, access_token)
        uri = URI.parse("https://www.googleapis.com/calendar/v3/calendars/#{calendar_id}/events")
        query = { singleEvents: 'true',
                  timeMin: DateTime.now.beginning_of_day.rfc3339,
                  timeMax: DateTime.now.end_of_day.rfc3339 }
        uri.query = URI.encode_www_form(query)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        req = Net::HTTP::Get.new(uri.request_uri)
        req['Accept'] = 'application/json'
        req['Authorization'] = "Bearer #{access_token}"
        res = http.request(req)
        res.body
      end

      def format_events_from_json(json_str, calendar_name)
        formated_events = []
        json = JSON.parse(json_str)
        json['items'].each do |event|
          start = event['start']['dateTime'] || event['start']['date']
          start_time = DateTime.parse(start).strftime('%H:%M:%S')
          summary = event['summary']
          formated_events.push([start_time, summary, calendar_name])
        end

        formated_events
      end
    end
  end # module Command
end # module Swimmy
