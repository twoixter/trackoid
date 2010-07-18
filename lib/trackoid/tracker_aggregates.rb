# encoding: utf-8
module Mongoid  #:nodoc:
  module Tracking
    # This internal class handles all interaction of an aggregation token.
    class TrackerAggregates

      def initialize(owner, token, key_selector, track_field = nil)
        @owner, @token = owner, token
        @key = key_selector
        @track_field = track_field

        @accessor = @owner.class.send(:internal_accessor_name, @token)
        @selector = {:ns => @token}
        @selector.merge!(:key => @key.first) if @key.first
        @criteria = @owner.send(@accessor).where(@selector)
      end

      # Delegate all missing methods to the underlying Mongoid Criteria
      def method_missing(name, *args, &block)
        @criteria.send(name)
      end

      # Access the aggregation collection with "collection" so that we can
      # use the original mongoid methods like "all", "first", etc.
      def collection
        @criteria
      end

      # Define all accessors here. Basically we are delegating to the Track
      # object for every object in the criteria
      [ :today, :yesterday, :last_days, :all, :first, :last,
        :first_date, :last_date
      ].each {|name|
        define_method(name) do |*args|
          @criteria.collect {|c|
            [c.key, c.send(@track_field).send(name)] if @track_field
          }
        end
      }

    end
  end
end