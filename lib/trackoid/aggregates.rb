# encoding: utf-8
module Mongoid  #:nodoc:
  module Tracking #:nodoc:
    module Aggregates
      # This module includes aggregate data extensions to Trackoid instances
      def self.included(base)
        base.class_eval do
          extend ClassMethods

          class_inheritable_accessor :aggregate_fields, :aggregate_klass
          self.aggregate_fields = {}
          self.aggregate_klass = nil
          delegate :aggregate_fields,
                   :aggregate_klass,
                   :aggregated?,
                      :to => "self.class"
        end
      end

      module ClassMethods
        # Defines an aggregate token to an already tracked model. It defines
        # a new mongoid model named after the original model.
        # 
        # Example:
        #
        # <tt>class Page</tt>
        # <tt>  include Mongoid::Document</tt>
        # <tt>  include Mongoid::Document</tt>
        # <tt>  track :visits</tt>
        # <tt>  aggregate :browsers do |b|</tt>
        # <tt>    b.split(" ").first</tt>
        # <tt>  end</tt>
        # <tt>end</tt>
        #
        # A new model is defined as <tt>class PageAggregates</tt>
        #
        # This model has the following structure:
        # 
        # <tt>belongs_to :page</tt>
        # <tt>field :ns, :type => String</tt>
        # <tt>field :key, :type => String</tt>
        # <tt>index [:ns, :key], :unique => true</tt>
        # <tt>track :[original_parent_tracking_data]</tt>
        # <tt>track :...</tt>
        #
        # :ns is the "namespace". It's the name you put along the
        # "aggregate :browsers" in the original model definition.
        #
        # :key is your aggregation key. This is the value you are required to
        # return in the "aggregate" block.
        #
        # With the above structure, you can always query aggregates directly
        # using Mongoid this way:
        #
        # <tt>TestModelAggregates.where(:ns => "browsers", :key => "explorer").first</tt>
        #
        # But you are encouraged to use Trackoid methods whenever possible.
        #
        def aggregate(name, &block)
          raise Errors::AggregationAlreadyDefined.new(self.name, name) if
              aggregate_fields.has_key? name

          define_aggregate_model if aggregate_klass.nil?
          has_many_related internal_accessor_name(name), :class_name => aggregate_klass.to_s
          add_aggregate_field(name, block)
          create_aggregation_accessors(name)
        end

        # Return true if this model has aggregated data.
        def aggregated?
          !aggregate_klass.nil?
        end

        protected
        # Returns the internal representation of the aggregates class name
        def internal_aggregates_name
          str = self.to_s.underscore + "_aggregates"
          str.camelize
        end

        def internal_accessor_name(name)
          (name.to_s + "_accessor").to_sym
        end

        # Defines the aggregation model. It checks for class name conflicts
        def define_aggregate_model
          raise Errors::ClassAlreadyDefined.new(internal_aggregates_name) if foreign_class_defined?
          parent_name = self.name.underscore
          define_klass do
            include Mongoid::Document
            include Mongoid::Tracking
            
            # Make the relation to the original class
            belongs_to_related parent_name.to_sym, :class_name => parent_name.camelize

            # Internal fields to track aggregation token and keys
            field :ns,  :type => String
            field :key, :type => String
            index [[:ns, Mongo::ASCENDING], [:key, Mongo::ASCENDING]], :unique => true, :background => true

            # Include parent tracking data.
            parent_name.camelize.constantize.tracked_fields.each {|track_field| track track_field }
          end
          self.aggregate_klass = internal_aggregates_name.constantize
        end

        # Returns true if there is a class defined with the same name as our
        # aggregate class.
        def foreign_class_defined?
          # The following construct doesn't work with namespaced constants.
          # Object.const_defined?(internal_aggregates_name.to_sym)
          internal_aggregates_name.constantize && true
        rescue NameError
          false
        end

        # Adds the aggregate field to the array of aggregated fields.
        def add_aggregate_field(name, block)
          aggregate_fields[name] = block
        end

        # Defines the aggregation external class. This class is named after
        # the original class model but with "Aggregates" appended.
        # Example:  TestModel ==> TestModelAggregates
        def define_klass(&block)
          scope = internal_aggregates_name.split('::')
          klass = scope.pop
          scope = scope.inject(Kernel) {|scope, const_name| scope.const_get(const_name)}
          klass = scope.const_set(klass, Class.new)
          klass.class_eval(&block)
        end

        def create_aggregation_accessors(name)
          # Aggregation accessors in the model acts like a named scope
          define_method(name) do |*args|
            TrackerAggregates.new(self, name, args)
          end

          define_method("#{name}_with_track") do |track_field, *args|
            TrackerAggregates.new(self, name, args, track_field)
          end

          define_method("#{name}=") do
            raise NoMethodError
          end
        end

      end
      
    end


    # class Aggregate
    #   include Mongoid::Document
    # end
    # 
    # track :visits
    # aggregate :browsers do
    #   ["google"]
    # end
    # aggregate :referers do
    #   ["domain.com"]
    # end
    # 
    # 
    # self.visits(agg).inc
    # self.visits.today
    # self.visits.browsers.today
    #
    # users
    #   { _id: 32334333, name:"pepe", visits_data:{} }
    # 
    # users_aggregates
    #   { _id: 11221223, data_for: 32334333, ns: "browsers", key: nil,  visits_data:{} }
    #   { _id: 11223223, data_for: 32334333, ns: "browsers", key: "google",  visits_data:{} }
    #   { _id: 11224432, data_for: 32334333, ns: "browsers", key: "firefox", visits_data:{} }
    # 
    # 
    # class UsersAggregate
    #   include Mongoid::Document
    #   include Mongoid::Tracking
    #   
    #   belongs_to :users
    #   field :ns
    #   field :key
    # 
    #   track :visits
    #   track :uniques
    # end
    # 
    # 

  end
end
