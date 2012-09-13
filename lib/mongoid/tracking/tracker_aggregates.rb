# encoding: utf-8
module Mongoid  #:nodoc:
  module Tracking
    # This internal class handles all interaction of an aggregation token.
    class TrackerAggregates

      def initialize(owner, token, key_selector, track_field = nil)
        @owner, @token = owner, token
        @key = key_selector.first
        @track_field = track_field

        @accessor = @owner.class.send(:internal_accessor_name, @token)
        @selector = { ns: @token }
        @selector.merge!(key: @key) if @key

        @criteria = @owner.send(@accessor).where(@selector)
      end

      # Delegate all missing methods to the underlying Mongoid Criteria
      def method_missing(name, *args, &block)
        @criteria.send(name)
      end

      # Define all readers here. Basically we are delegating to the Track
      # object for every object in the criteria
      Readers.instance_methods.each {|name|
        define_method(name) do |*args|
          return nil unless @track_field
          if @key
            res = @criteria.first
            res.send(@track_field).send(name, *args) if res
          else
            @criteria.collect {|c|
              [c.key, c.send(@track_field).send(name, *args)]
            }
          end
        end
      }

    end
  end
end