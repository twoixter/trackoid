# encoding: utf-8
class Range
  # Adds some enumerable capabilities to Time ranges
  # (Normally they raise a "Can't iterate time ranges")
  #
  # It works by assuming days while iterating the time range, but you can
  # pass an optional parameter

  HOURS = 3600
  DAYS = 24*HOURS
  DEFAULT_TIME_GRANULARITY = DAYS

  # Map / Collect over a Time range.
  # A better implementation would be redefining 'succ' on Time. However,
  # the ruby source code (At least 1.9.2-p0) hardcodes a check for Type,
  # so it would not work even if we provide our own 'succ' for Time.
  def collect(step = DEFAULT_TIME_GRANULARITY)
    return super() unless first.is_a?(Time)

    return collect(step) {|c| c} unless block_given?

    # Pretty much a standard implementation of Map/Collect here
    ary, current, op = [], first, (exclude_end? ? :< : :<=)
    while current.send(op, last)
      ary << yield(current)
      current = current + step
    end 
    ary
  end
  alias :map :collect

  # Diff returns the number of elements in the Range, much like 'count'.
  # Again, redefining 'succ' would be a better idea (see above).
  # However, I think redefining 'succ' makes this O(n) while this is O(1)
  def diff(granularity = DEFAULT_TIME_GRANULARITY)
    if first.is_a?(Time)
      @diff ||= (last - first) / granularity + (exclude_end? ? 0 : 1)
      @diff.to_i
    else
      @diff ||= count
    end
  end

  # Helper methods for non default parameters
  def hour_diff
    diff(HOURS)
  end

  def hour_collect(&block)
    collect(HOURS, &block)
  end
  alias :hour_map :hour_collect
end
