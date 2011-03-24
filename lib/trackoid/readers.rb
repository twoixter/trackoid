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
        # We are guaranteed _m and _d to exists unless @data is a malformed
        # hash, so we need to do this nasty "return nil", sorry...
        # TODO: I'm open to change this to a cleaner algorithm :-)
        return nil unless _y = @data.keys.min
        return nil unless _m = @data[_y].keys.min
        return nil unless _d = @data[_y][_m].keys.min
        Date.new(_y.to_i, _m.to_i, _d.to_i)
      end
      
      def last_date
        # We are guaranteed _m and _d to exists unless @data is a malformed
        # hash, so we need to do this nasty "return nil", sorry...
        # TODO: I'm open to change this to a cleaner algorithm :-)
        return nil unless _y = @data.keys.max
        return nil unless _m = @data[_y].keys.max
        return nil unless _d = @data[_y][_m].keys.max
        Date.new(_y.to_i, _m.to_i, _d.to_i)
      end

    end
  end
end
