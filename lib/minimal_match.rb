require 'singleton'
module MinimalMatch
  module ProxyOperators
    # it's easier to just set this directly on these objects
    # rather than to construct the heuristic for determining
    # the classification and having to update it when
    # we want to add new operators
    def is_proxy? obj
      obj.instance_variable_get :@is_proxy
    end

    def is_match_op? obj
      obj.instance_variable_get :@is_match_op
    end
  end
  extend ProxyOperators
end

require 'minimal_match/minimal_match'
require 'minimal_match/minimal_search'

