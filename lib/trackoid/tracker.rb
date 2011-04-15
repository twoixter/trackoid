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
      def add(how_much = 1, date = Time.now)
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
            :upsert => true, :safe => false
        )
        return unless @owner.aggregated?

        @owner.aggregate_fields.each do |(k,v)|
          next unless token = v.call(@aggregate_data)
          fk = @owner.class.name.to_s.foreign_key.to_sym
          selector = { fk => @owner.id, :ns => k, :key => token.to_s }
          @owner.aggregate_klass.collection.update(
              selector,
              { (how_much > 0 ? "$inc" : "$dec") => update_hash(how_much.abs, date) },
              :upsert => true, :safe => false
          )
        end
      end

      def inc(date = Time.now)
        add(1, date)
      end

      def dec(date = Time.now)
        add(-1, date)
      end

      def set(how_much, date = Time.now)
        raise Errors::ModelNotSaved, "Can't update a new record" if @owner.new_record?
        update_data(how_much, date)
        @owner.collection.update(
            @owner._selector, { "$set" => update_hash(how_much, date) },
            :upsert => true, :safe => false
        )
        return unless @owner.aggregated?

        @owner.aggregate_fields.each do |(k,v)|
          next unless token = v.call(@aggregate_data)
          fk = @owner.class.name.to_s.foreign_key.to_sym
          selector = { fk => @owner.id, :ns => k, :key => token.to_s }
          @owner.aggregate_klass.collection.update(
              selector, { "$set" => update_hash(how_much, date) },
              :upsert => true, :safe => false
          )
        end
      end

      def reset(how_much, date = Time.now)
        return erase(date) if how_much.nil?

        # First, we use the default "set" for the tracking field
        # This will also update one aggregate but... oh well...
        set(how_much, date)

        # Need to iterate over all aggregates and send an update or delete
        # operations over all mongo records for this aggregate field
        @owner.aggregate_fields.each do |(k,v)|
          fk = @owner.class.name.to_s.foreign_key.to_sym
          selector = { fk => @owner.id, :ns => k }
          @owner.aggregate_klass.collection.update(
              selector, { "$set" => update_hash(how_much, date) },
              :upsert => true, :multi => true, :safe => false
          )
        end
      end

      def erase(date = Time.now)
        raise Errors::ModelNotSaved, "Can't update a new record" if @owner.new_record?

        remove_data(date)
        @owner.collection.update(
            @owner._selector,
            { "$unset" => update_hash(1, date) },
            :upsert => true, :safe => false
        )
        return unless @owner.aggregated?

        # Need to iterate over all aggregates and send an update or delete
        # operations over all mongo records
        @owner.aggregate_fields.each do |(k,v)|
          fk = @owner.class.name.to_s.foreign_key.to_sym
          selector = { fk => @owner.id, :ns => k }
          @owner.aggregate_klass.collection.update(
              selector, { "$unset" => update_hash(1, date) },
              :upsert => true, :multi => true, :safe => false
          )
        end
      end

      private
      def data_for(date)
        unless date.nil?
          date = normalize_date(date)
          @data.try(:[], date.to_i_timestamp.to_s).try(:[], date.to_i_hour.to_s) || 0
        end
      end

      def whole_data_for(date)
        unless date.nil?
          date = normalize_date(date)
          h = date.whole_day.hour_collect {|d| data_for(d)}
          ReaderExtender.new(h.sum, h)
        end
      end

      def update_data(value, date)
        unless date.nil?
          return remove_data(date) unless value
          date = normalize_date(date)
          dk, hk = date.to_i_timestamp.to_s, date.to_i_hour.to_s
          unless ts = @data[dk]
            ts = (@data[dk] = {})
          end
          ts[hk] = value
        end
      end

      def remove_data(date)
        unless date.nil?
          date = normalize_date(date)
          dk, hk = date.to_i_timestamp.to_s, date.to_i_hour.to_s
          if ts = @data[dk]
            ts.delete(hk)
            unless ts.count > 0
              @data.delete(dk)
            end
          end
        end
      end

      def update_hash(num, date)
        date = normalize_date(date)
        {
          "#{@for_data}.#{date.to_key}" => num
        }
      end

      def normalize_date(date)
        case date
        when String
          Time.parse(date)
        when Date
          date.to_time
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
