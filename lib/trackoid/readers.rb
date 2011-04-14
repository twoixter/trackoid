# encoding: utf-8
module Mongoid  #:nodoc:
  module Tracking
    # Reader methods (previously known as "accessors")
    module Readers

      # Access methods
      def today
        whole_data_for(Time.now)
      end

      def yesterday
        whole_data_for(Time.now - 1.day)
      end

      def first_value
        data_for(first_date)
      end

      def last_value
        data_for(last_date)
      end

      def last_days(how_much = 7)
        return [today] unless how_much > 0
        now, hmd = Time.now, (how_much - 1)
        on( now.ago(hmd.days)..now )
      end

      def on(date)
        return date.collect {|d| whole_data_for(d)} if date.is_a?(Range)
        whole_data_for(date)
      end

      def all_values
        on(first_date..last_date) if first_date
      end

      # Utility methods
      def first_date
        date_cleanup
        return nil unless _ts = @data.keys.min
        return nil unless _h = @data[_ts].keys.min
        Time.from_key(_ts, _h)
      end

      def last_date
        date_cleanup
        return nil unless _ts = @data.keys.max
        return nil unless _h = @data[_ts].keys.max
        Time.from_key(_ts, _h)
      end

      # We need the cleanup method only for methods who rely on date indexes
      # to be valid (well formed) like first/last_date. This is because
      # Mongo update operations cleans up the last key, which in our case
      # left the array in an inconsistent state.
      #
      # Example:
      # Before update:
      #
      #  { :visits_data => {"14803" => {"22" => 1} } }
      #
      # After updating with:  {"$unset"=>{"visits_data.14803.22"=>1}
      #
      #  { :visits_data => {"14803" => {} } }
      #
      # We can NOT retrieve the first date with visits_data.keys.min
      #
      def date_cleanup
        @data.reject! {|k,v| v.count == 0}
      end
    end
  end
end
