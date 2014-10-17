
def overlaps?(a,b)
    (a.first - b.last) * (b.first - a.last) >= 0
end
    
def merge_ranges(ranges)
  if (ranges.nil? || ranges.empty?)
    return nil
  end
  ranges = ranges.sort_by {|r| r.first }
  *outages = ranges.shift
  ranges.each do |r|
    lastr = outages[-1]
    if lastr.last >= r.first - 1
      outages[-1] = lastr.first..[r.last, lastr.last].max
    else
      outages.push(r)
    end
  end
  outages.sort_by {|r| r.first }
  outages
end

def in_ranges?(ranges,range)
  if ranges
    ranges.each do |r|
      if overlaps?(range,r)
        return true
      end
    end
  end
  return false
end
