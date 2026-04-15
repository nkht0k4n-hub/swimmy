# coding: utf-8
require 'json'
require 'uri'
require 'net/https'
require 'pp'
require 'date'
require 'fileutils'
require 'active_support/time'

module Swimmy
  module Service
    class CalendarService

      def initialize
        @google_oauth ||= begin
            Swimmy::Resource::GoogleOAuth.new('config/credentials.json', 'config/tokens.json')
        rescue e
          return
        end
      end

      def get_events(calendars,keyword)
        events = []
        calendars.each do |calendar|
          events.concat(get_event(calendar.id, calendar.name))
        end

        if !keyword.nil? then
          events = search_keyword_events(events,keyword)
        end
        events = events.sort_by{|x| x.start}
        return events
      end

      private

      def get_event(calendar_id, calendar_name)
        events = []
        raw_events = fetch_info(calendar_id, @google_oauth.token)
        events = format_events_from_json(raw_events, calendar_name)
        return events
      end

      def fetch_info(calendar_id, access_token)
        uri = URI.parse("https://www.googleapis.com/calendar/v3/calendars/#{calendar_id}/events")
        now = DateTime.now
        future = now >> 1
        query = { singleEvents: 'true',
                  timeMin: now.rfc3339,
                 timeMax: future.rfc3339}
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
          #end = event['end']['dateTime'] || event['end']['date']
          summary = event['summary']
          formated_events.push(Swimmy::Resource::Event.new(start, summary, calendar_name))
        end
  
        formated_events
      end

      def search_keyword_events(events,keyword)
        keyword_events = []
        events.each do |event|
          if event.start.strftime('%m月%d日').match?(keyword) || event.summary.match?(keyword) || event.calendar_name.match?(keyword) then
            keyword_events.push(event)
          else
            next
          end
        end
        keyword_events
      end

    end
  end
end
