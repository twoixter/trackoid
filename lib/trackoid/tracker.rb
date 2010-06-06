# encoding: utf-8
module Mongoid  #:nodoc:
  module Tracking
    # This internal class handles all interaction for a track field.
    class Tracker
      
      def initialize(owner, field, aggregate_data)
        @owner, @for = owner, field
        @for_data = @owner.internal_track_name(@for)
        @data = @owner.read_attribute(@for_data)
        
        # The following is needed if the "field" Mongoid definition for our
        # internal tracking field does not include option ":default => {}"
        if @data.nil?
          @owner.write_attribute(@for_data, {})
          @data = @owner.read_attribute(@for_data)
        end

        @aggregate_data = aggregate_data.first if aggregate_data.first
      end

      # Delegate all missing methods to the aggregate accessors. This enables
      # us to call an aggregation token after the tracking field.
      #
      # Example:
      #
      #   <tt>@object.visits.browsers ...</tt>
      #
      def method_missing(name, *args, &block)
        super unless @owner.aggregate_fields.member?(name)
        @owner.send("#{name}_with_track".to_sym, @for, *args, &block)
      end

      # Update methods
      def add(how_much = 1, date = DateTime.now)
        raise Errors::ModelNotSaved, "Can't update a new record" if @owner.new_record?
        update_data(data_for(date) + how_much, date)

        @owner.collection.update( @owner._selector,
            { (how_much > 0 ? "$inc" : "$dec") => update_hash(how_much.abs, date) },
            :upsert => true)

        return unless @owner.aggregated?

        @owner.aggregate_fields.each do |(k,v)|
          next unless token = v.call(@aggregate_data)
          
          fk = @owner.class.name.to_s.foreign_key.to_sym
          selector = { fk => @owner.id, :ns => k, :key => token.to_s }
          @owner.aggregate_klass.collection.update( selector,
              { (how_much > 0 ? "$inc" : "$dec") => update_hash(how_much.abs, date) },
              :upsert => true)
        end
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
        return 0 if @data.nil? ||
                    @data[date.year.to_s].nil? ||
                    @data[date.year.to_s][date.month.to_s].nil?
        @data[date.year.to_s][date.month.to_s][date.day.to_s] || 0
      end

      # TODO: It should be a better way of updating a hash. :-)
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
          "#{@for_data}.#{date_literal(date)}" => num
        }
      end

      # WARNING: This is +only+ for debugging pourposes (rspec y tal)
      def _original_hash
        @data
      end

    end

  end
end
