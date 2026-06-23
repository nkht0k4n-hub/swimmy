require 'time'

module Swimmy
  module Resource
    class RTask
      attr_reader :id, :content, :due_at

      def initialize(attributes)
        @id = attributes["id"]
        @content = attributes["content"]
        @due_at = parse_due_at(attributes["due_at"])
      end

      def due_this_month?(base_date)
        return false unless due_at
        due_at.year == base_date.year && due_at.month == base_date.month
      end

      def url(rask_url)
        return '' if rask_url.empty? || id.nil?
        "#{rask_url}/tasks/#{id}"
      end

      private

      def parse_due_at(value)
        return nil if value.nil? || value.empty?
        Time.parse(value)
      rescue ArgumentError
        nil
      end
    end
  end
end
