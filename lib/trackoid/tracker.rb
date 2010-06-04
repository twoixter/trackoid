# encoding: utf-8
module Mongoid  #:nodoc:
  module Tracking
    # This internal class handles all interaction for a track field.
    class Tracker
      def initialize(owner, field)
        @owner, @for = owner, field
        @data = @owner.read_attribute(@for) || {}
      end

      # Update methods
      def add(how_much = 1, date = DateTime.now)
        raise Errors::ModelNotSaved, "Can't update a new record" if @owner.new_record?

        update_data(data_for(date) + how_much, date)
        @owner.collection.update( @owner._selector,
            { (how_much > 0 ? "$inc" : "$dec") => update_hash(how_much.abs, date) },
            :upsert => true)
      end

      def inc(date = DateTime.now)
        add(1, date)
      end

      def dec(date = DateTime.now)
        add(-1, date)
      end

      def set(how_much, date = DateTime.now)
        raise Errors::ModelNotSaved, "Can't update a new record" if @owner.new_record?

        update_data(how_much, date)
        @owner.collection.update( @owner._selector,
            { "$set" => update_hash(how_much, date) },
            :upsert => true)
      end

      # Access methods
      def today
        data_for(Date.today)
      end

      def yesterday
        data_for(Date.today - 1)
      end

      def last_days(how_much = 7)
        return [today] unless how_much > 0

        date, values = DateTime.now, []
        (date - how_much.abs + 1).step(date) {|d| values << data_for(d) }
        values
      end

      def on(date)
        date = DateTime.parse(date) if date.is_a?(String)
        return date.collect {|d| data_for(d)} if date.is_a?(Range)
        data_for(date)
      end

      # Private methods
      private
      def data_for(date)
        return 0 if @data[date.year.to_s].nil?
        return 0 if @data[date.year.to_s][date.month.to_s].nil?
        @data[date.year.to_s][date.month.to_s][date.day.to_s] || 0
      end

      def update_data(value, date)
        if @data[date.year.to_s]
          if @data[date.year.to_s][date.month.to_s]
            @data[date.year.to_s][date.month.to_s][date.day.to_s] = value
          else
            @data[date.year.to_s][date.month.to_s] = {
                date.day.to_s => value
            }
          end
        else
          @data[date.year.to_s] = {
            date.month.to_s => {
              date.day.to_s => value
            }
          }
        end
      end

      def year_literal(d);  "#{d.year}"; end
      def month_literal(d); "#{d.year}.#{d.month}"; end
      def date_literal(d);  "#{d.year}.#{d.month}.#{d.day}"; end

      def update_hash(num, date)
        {
          "#{@for}.#{date_literal(date)}" => num
        }
      end


      # WARNING: This is +only+ for debugging pourposes (rspec y tal)
      def _original_hash
        @data
      end

    end

  end
end
