# encoding: utf-8
module Mongoid  #:nodoc:
  module Tracking
    # Reader methods (previously known as "accessors")
    module Readers

      # Access methods
      def today
        data_for(Date.today)
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
        if _y = @data.keys.min and  _m = @data[_y].keys.min and _d = @data[_y][_m].keys.min
          Date.new(_y.to_i, _m.to_i, _d.to_i)
        end
      end
      
      def last_date
        if _y = @data.keys.max and  _m = @data[_y].keys.max and _d = @data[_y][_m].keys.max
          Date.new(_y.to_i, _m.to_i, _d.to_i)
        end
      end

    end
  end
end
