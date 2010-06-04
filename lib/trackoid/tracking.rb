# encoding: utf-8
module Mongoid #:nodoc:
  module Tracking #:nodoc:

    # Include this module to add analytics tracking into a +root level+ document.
    # Use "track :field" to add a field named :field and an associated mongoid
    # field named after :field
    def self.included(base)
      base.class_eval do
        raise Errors::NotMongoid, "Must be included in a Mongoid::Document" unless self.ancestors.include? Mongoid::Document

        include Aggregates
        extend ClassMethods
        
        class_inheritable_accessor :tracked_fields
        self.tracked_fields = []
        delegate :tracked_fields, :internal_track_name, :to => "self.class"
      end
    end

    module ClassMethods
      # Adds analytics tracking for +name+. Adds a +'name'_data+ mongoid
      # field as a Hash for tracking this information. Additionaly, makes
      # this field hidden, so that the user can not mangle with the original
      # field. This is necessary so that Mongoid does not "dirty" the field
      # potentially overwriting the original data.
      def track(name)
        set_tracking_field(name)
        create_tracking_accessors(name)
      end

      protected
      # Returns the internal representation of the tracked field name
      def internal_track_name(name)
        "#{name}_data".to_sym
      end

      # Configures the internal fields for tracking. Additionally also creates
      # an index for the internal tracking field.
      def set_tracking_field(name)
        field internal_track_name(name), :type => Hash, :default => {}
        # Shoul we make an index for this field?
        index internal_track_name(name)
        tracked_fields << internal_track_name(name)
      end
      
      # Creates the tracking field accessor and also disables the original
      # ones from Mongoid. Hidding here the original accessors for the
      # Mongoid fields ensures they doesn't get dirty, so Mongoid does not
      # overwrite old data.
      def create_tracking_accessors(name)
        define_method("#{name}") do
          Tracker.new(self, "#{name}_data".to_sym)
        end

        # Should we just "undef" this methods?
        # They override the ones defined from Mongoid
        define_method("#{name}_data") do
          raise NoMethodError
        end

        define_method("#{name}_data=") do
          raise NoMethodError
        end
      end
      
    end

  end
end
