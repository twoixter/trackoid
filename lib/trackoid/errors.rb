# encoding: utf-8
module Mongoid #:nodoc
  module Errors #:nodoc

    class ClassAlreadyDefined < RuntimeError
      def initialize(klass)
        @klass = klass
      end
      def message
        "#{@klass} already defined, can't aggregate!"
      end
    end

    class ModelNotSaved < RuntimeError; end

    class NotMongoid < RuntimeError; end
    
  end
end
