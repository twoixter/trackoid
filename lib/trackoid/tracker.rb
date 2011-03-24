# encoding: utf-8
module Mongoid  #:nodoc:
  module Tracking
    # This internal class handles all interaction for a track field.
    class Tracker

      include Readers

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
      def add(how_much = 1, date = Date.today)
        raise Errors::ModelNotSaved, "Can't update a new record. Save first!" if @owner.new_record?
        return if how_much == 0

        # Note that the following #update_data method updates our local data
        # and the current value might differ from the actual value on the
        # database. Basically, what we do is update our own copy as a cache
        # but send the command to atomically update the database: we don't
        # read the actual value in return so that we save round trip delays.
        #
        update_data(data_for(date) + how_much, date)
        @owner.collection.update(
            @owner._selector,
            { (how_much > 0 ? "$inc" : "$dec") => update_hash(how_much.abs, date) },
            :upsert => true
        )
        return unless @owner.aggregated?

        @owner.aggregate_fields.each do |(k,v)|
          next unless token = v.call(@aggregate_data)
          fk = @owner.class.name.to_s.foreign_key.to_sym
          selector = { fk => @owner.id, :ns => k, :key => token.to_s }
          @owner.aggregate_klass.collection.update(
              selector,
              { (how_much > 0 ? "$inc" : "$dec") => update_hash(how_much.abs, date) },
              :upsert => true
          )
        end
      end

      def inc(date = Date.today)
        add(1, date)
      end

      def dec(date = Date.today)
        add(-1, date)
      end

      def set(how_much, date = Date.today)
        raise Errors::ModelNotSaved, "Can't update a new record" if @owner.new_record?
        update_data(how_much, date)
        @owner.collection.update(
            @owner._selector,
            { "$set" => update_hash(how_much, date) },
            :upsert => true
        )
        return unless @owner.aggregated?

        @owner.aggregate_fields.each do |(k,v)|
          next unless token = v.call(@aggregate_data)
          fk = @owner.class.name.to_s.foreign_key.to_sym
          selector = { fk => @owner.id, :ns => k, :key => token.to_s }
          @owner.aggregate_klass.collection.update(
              selector,
              { "$set" => update_hash(how_much, date) },
              :upsert => true
          )
        end
      end

      private
      def data_for(date)
        return nil if date.nil?
        date = normalize_date(date)
        @data.try(:[], date.year.to_s).try(:[], date.month.to_s).try(:[], date.day.to_s) || 0
      end

      def update_data(value, date)
        return nil if date.nil?
        date = normalize_date(date)
        [:year, :month].inject(@data) { |data, period|
          data[date.send(period).to_s] ||= {}
        }
        @data[date.year.to_s][date.month.to_s][date.day.to_s] = value
      end

      def year_literal(d);  "#{d.year}"; end
      def month_literal(d); "#{d.year}.#{d.month}"; end
      def date_literal(d);  "#{d.year}.#{d.month}.#{d.day}"; end

      def update_hash(num, date)
        date = normalize_date(date)
        {
          "#{@for_data}.#{date_literal(date)}" => num
        }
      end

      def normalize_date(date)
        case date
        when String
          Date.parse(date)
        else
          date
        end
      end

      # WARNING: This is +only+ for debugging purposes (rspec y tal)
      def _original_hash
        @data
      end

    end

  end
end
