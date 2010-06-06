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

      # REFACTOR THIS
      # WE ARE DOING SOMETHING LIKE:
      #
      # => browsers("something").visits
      #
      # WHILE A BEST APPROACH IS LIKE
      #
      # => visits.browsers("something")

      # visits (Tracker) -> browsers (TrackerAggregates) -> count (to Criteria)
      #                                                  -> today (data)

      # Delegate all missing methods to the underlying Mongoid Criteria
      def method_missing(name, *args, &block)
        @criteria.send(name)

        # Delegate all missing methods to the underlying Mongoid Criteria
        # return @criteria.send(name) unless @owner.tracked_fields.member?(name)
        # super
        
        # Otherwise, it's a track method, so process it
        # @criteria.collect {|x| x.send(name, *args, &block) }
      end

      def today
        @criteria.collect {|c|
          [c.key, c.send(@track_field).today] if @track_field
        }
      end

      def yesterday
        @criteria.collect {|c|
          [c.key, c.send(@track_field).yesterday] if @track_field
        }
      end

      def last_days(how_much = 7)
        @criteria.collect {|c|
          [c.key, c.send(@track_field).last_days(how_much)] if @track_field
        }
      end

    end

  end
end