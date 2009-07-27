# Build an array based on an input string with a token to be replaced and an input array of values
Puppet::Parser::Functions::newfunction(:testing, :type => :rvalue, :doc => "A function that accepts a normal string
    and an array. The function returns an array that contains each of the input
    array's values, merged with the string. Merging is performed by replacing
    the <VAL> token in the string with the array value. If no <VAL> token
    exists, the array string is appended to the end of the string.") do |args|
        token = '<VAL>'
        inputstring = args[0]

        puts "args: %s" % args.inspect

        if args[1] then
            outputstrings = Array.new
            args[1].each do |val|
                puts "val %s" % val
                puts "outp bef %s" % outputstrings.inspect
                 if inputstring.match(token) then
                     outputstrings << inputstring.sub(token, val)
                 else
                     outputstrings << inputstring + val
                 end
                 puts "outp %s" % outputstrings.inspect
            end
        else
            return false
        end

        puts "outputstrings: %s" % outputstrings.inspect

        return outputstrings
end
