module Mongoid  #:nodoc:
  module Tracking

    module Aggregates
      # This module includes aggregate data extensions to Trackoid instances
      def self.included(base)
        base.class_eval do
          extend ClassMethods
          include InstanceMethods

          class_inheritable_accessor :aggregate_fields, :aggregate_klass
          self.aggregate_fields = []
          self.aggregate_klass = nil
#          delegate :aggregate_fields, :aggregate_klass, :to => "self.class"
        end
      end

      module ClassMethods

        def aggregate(name, &block)
          define_aggregate_model if aggregate_klass.nil?
          has_many name.to_sym, :class_name => aggregate_klass.to_s
          add_aggregate_field(name, block)
        end

        protected
        # Returns the internal representation of the aggregates class name
        def internal_aggregates_name
          str = self.to_s.underscore + "_aggregates"
          str.camelize
        end

        def define_aggregate_model
          raise Errors::ClassAlreadyDefined.new(internal_aggregates_name) if foreign_class_defined
          define_klass do
            include Mongoid::Document
            include Mongoid::Tracking
            field :name, :type => String, :default => "Dummy Text"
#            belongs_to :
          end
          self.aggregate_klass = internal_aggregates_name.constantize
        end
        
        def foreign_class_defined
          Object.const_defined?(internal_aggregates_name.to_sym)
        end

        def add_aggregate_field(name, block)
          aggregate_fields << { name => block }
        end

        def define_klass(&block)
          # klass = Class.new Object, &block
          klass = Object.const_set internal_aggregates_name, Class.new
          klass.class_eval(&block)
        end

      end
      
      module InstanceMethods
        def aggregated?
          !self.class.aggregate_klass.nil?
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
    # self.visits.inc("Google engine")
    # 
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
