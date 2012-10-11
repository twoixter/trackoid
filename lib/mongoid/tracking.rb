# encoding: utf-8
module Mongoid #:nodoc:
  module Tracking #:nodoc:

    # Include this module to add analytics tracking into a +root level+ document.
    # Use "track :field" to add a field named :field and an associated mongoid
    # field named after :field
    def self.included(base)
      base.class_eval do
        unless self.ancestors.include? Mongoid::Document
          raise Errors::NotMongoid, "Must be included in a Mongoid::Document"
        end

        include Aggregates
        extend ClassMethods

        class_attribute :tracked_fields
        self.tracked_fields = []
        delegate :tracked_fields, :internal_track_name, to: "self.class"
      end
    end

    module ClassMethods
      # Adds analytics tracking for +name+. Adds a +'name'_data+ mongoid
      # field as a Hash for tracking this information. Additionaly, hiddes
      # the field, so that the user can not mangle with the original one.
      # This is necessary so that Mongoid does not "dirty" the field
      # potentially overwriting the original data.
      def track(name)
        set_tracking_field(name.to_sym)
        create_tracking_accessors(name.to_sym)
        update_aggregates(name.to_sym) if aggregated?
      end

      protected
      # Returns the internal representation of the tracked field name
      def internal_track_name(name)
        "#{name}_data".to_sym
      end

      # Configures the internal fields for tracking. Additionally also creates
      # an index for the internal tracking field.
      def set_tracking_field(name)
        # DONT make an index for this field. MongoDB indexes have limited
        # size and seems that this is not a good target for indexing.
        # index internal_track_name(name)
        tracked_fields << name
      end

      # Creates the tracking field accessor and also disables the original
      # ones from Mongoid. Hidding here the original accessors for the
      # Mongoid fields ensures they doesn't get dirty, so Mongoid does not
      # overwrite old data.
      def create_tracking_accessors(name)
        define_method(name) do |*aggr|
          Tracker.new(self, name, aggr)
        end
      end

      # Updates the aggregated class for it to include a new tracking field
      def update_aggregates(name)
        aggregate_klass.track name
      end

    end

  end
end
