#
# slice.rb
#

module Puppet::Parser::Functions
  newfunction(:slice, :type => :rvalue, :doc => <<-EOS
    Returns a scliced string or array starting at the offset given by the
    second argument, and a length given by the third argument.

    *Examples:*

      slice('hello world', 0, 5)

    Would return:

      'hello'
    EOS
  ) do |arguments|

    if (arguments.size != 3) then
      raise(Puppet::ParseError, "slice(): Wrong number of arguments " +
        "given (#{arguments.size} for 3)")
    end

    value = arguments[0]
    klass = value.class
    i_start = arguments[1]
    i_end = arguments[2]

    unless [Array, String].include?(klass)
      raise(Puppet::ParseError, 'slice(): Requires either ' +
        'array or string to work with')
    end

    # Numbers in Puppet are often string-encoded which is troublesome ...
    if i_start.is_a?(String)
      if i_start.match(/^-?\d+$/)
        i_start = i_start.to_i
      else
        raise(Puppet::ParseError, 'slice(): Requires integer to work with')
      end
    end

    if i_end.is_a?(String)
      if i_end.match(/^-?\d+$/)
        i_end = i_end.to_i
      else
        raise(Puppet::ParseError, 'slice(): Requires integer to work with')
      end
    end

    result = value.slice(i_start, i_end)

    return result
  end
end

# vim: set ts=2 sw=2 et :