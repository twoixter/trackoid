# encoding: utf-8
module Mongoid  #:nodoc:
  module Tracking

    # ReaderExtender is used in cases where we need to return an integer
    # (class Numeric) while extending their contents. It would allow to
    # perform advanced calculations in some situations:
    #
    # Example:
    #
    #   a = visits.today   # Would return a number, but "extended" so that
    #                      # we can make a.hourly to get a detailed, hourly
    #                      # array of the visits.
    #
    #   b = visits.yesterday
    #   c = a + b          # Here, in c, normally we would have a FixNum with
    #                      # the sum of a plus b, but if we extend the sum
    #                      # operation, we can additionaly sum the hourly
    #                      # array and return a new ReaderExtender c.
    #
    class ReaderExtender
      def initialize(number, hours)
        @total = number
        @hours = hours
      end

      def hourly
        @hours
      end

      def to_s
        @total.to_s
      end

      def to_f
        @total.to_f
      end

      def ==(other)
        @total == other
      end

      def <=>(other)
        @total <=> other
      end

      def +(other)
        return @total + other unless other.is_a?(ReaderExtender)

        @total = @total + other
        @hours = @hours.zip(other.hourly).map!(&:sum)
        self
      end

      # Solution proposed by Yehuda Katz in the following Stack Overflow:
      # http://stackoverflow.com/questions/1095789/sub-classing-fixnum-in-ruby
      #
      # Basically we override our methods while proxying all missing methods
      # to the underliying FixNum
      #
      def method_missing(name, *args, &blk)
        ret = @total.send(name, *args, &blk)
        ret.is_a?(Numeric) ? ReaderExtender.new(ret, @hours) : ret
      end
    end

  end
end
