# encoding: utf-8
module Mongoid  #:nodoc:
  module Tracking
    # This internal class handles all interaction of an aggregation token.
    class TrackerAggregates

      def initialize(owner, token, key_selector)
        @owner, @token = owner, token
        @key = key_selector

        @accessor = @owner.class.send(:internal_accessor_name, @token)
        @selector = {:ns => @token}
        @selector.merge!(:key => @key.first) if @key.first
      end

      def method_missing(name, *args, &block)
        @criteria ||= @owner.send(@accessor).where(@selector)
        
        # Delegate all missing methods to the underlying Mongoid Criteria
        return @criteria.send(name) unless @owner.tracked_fields.member?(name)
        
        # Otherwise, it's a track method, so process it
        @criteria.collect {|x| x.send(name, *args, &block) }
      end

    end

  end
end