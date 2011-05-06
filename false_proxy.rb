require_relative './lib/minimal_match'


x = m(false)

set_trace_func proc { |event, file, line, id, binding, classname|
  printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
  }

if x
  true
end

