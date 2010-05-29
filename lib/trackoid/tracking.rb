# encoding: utf-8
require 'trackoid/tracker'

module Mongoid #:nodoc:
  module Tracking
    # Include this module to add analytics tracking into a +root level+ document.
    # Use "track :field" to add a field named :field and an associated mongoid
    # field named after :field
    def self.included(base)
      base.class_eval do
        raise "Must be included in a Mongoid::Document" unless self.ancestors.include? Mongoid::Document
        extend ClassMethods
      end
    end

    module ClassMethods
      # Adds analytics tracking for +name+. Adds a +'name'_data+ mongoid
      # field as a Hash for tracking this information. Additionaly, makes
      # this field hidden, so that the user can not mangle with the original
      # field. This is necessary so that Mongoid does not "dirty" the field
      # potentially overwriting the original data.
      def track(name)
        name_sym = "#{name}_data".to_sym
        field name_sym, :type => Hash, :default => {}
        
        # Shoul we index this field?
        index name_sym

        define_method("#{name}") do
          Tracker.new(self, name_sym)
        end

        # Should we just "undef" this methods?
        # They override the just defined ones from Mongoid
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
