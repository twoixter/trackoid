# encoding: utf-8
module Mongoid  #:nodoc:
  module Tracking
    # Reader methods (previously known as "accessors")
    module Readers

      # Access methods
      def today
        data_for(Time.now)
      end

      def yesterday
        data_for(Date.today - 1)
      end

      def first_value
        data_for(first_date)
      end

      def last_value
        data_for(last_date)
      end
      
      def last_days(how_much = 7)
        return [today] unless how_much > 0
        date, values = Date.today, []
        (date - how_much.abs + 1).step(date) {|d| values << data_for(d) }
        values
      end

      def on(date)
        return date.collect {|d| data_for(d)} if date.is_a?(Range)
        data_for(date)
      end

      def all_values
        on(first_date..last_date) if first_date
      end

      # Utility methods
      def first_date
        return nil unless _ts = @data.keys.min
        return nil unless _h = @data[_ts].keys.min
        Time.from_key(_ts, _h)
      end

      def last_date
        return nil unless _ts = @data.keys.max
        return nil unless _h = @data[_ts].keys.max
        Time.from_key(_ts, _h)
      end

    end
  end
end
