$counter = 0

def unique(name='%_')
  $counter += 1
  "#{name}#{$counter}"
end

def translate(expr, env)
  case expr
  when Numeric
    "i32 #{expr}"
  when Symbol
    retval = unique()
    puts "#{retval} = load i32* #{env[expr]}"
    retval
  when Array
    l = expr
    pred = l.first

    case pred
    when :fn
      name = l[1]
      params = l[2]
      body = l[3..-1]

      newenv = {}
      arglist = params.map{|a, t| "i32 %#{a}"}

      puts "define i32 @#{name}(#{arglist.join(", ")}) {"

      params.each do |sym|
        p = "%#{sym}"
        symname = unique(p)
        puts "#{symname} = alloca i32"
        puts "store i32 #{p}, i32* #{symname}"
        newenv[sym] = symname
      end

      retval = "void"
      body.each do |e|
        retval = translate(e, newenv)
      end
      puts "ret #{retval}"
      puts "}"
    when :let
      varlist = l[1]
      newenv = env.clone
      varlist.each do |argpair|
        sym = argpair[0]
        expr = argpair[1]

        val = translate(expr, newenv)
        symname = unique("%#{sym}")
        puts "#{symname} = alloca i32"
        puts "store i32 #{val}, i32* #{symname}"
        newenv[sym] = symname
      end

      body = l[2..-1]
      retval = nil
      body.each do |e|
        retval = translate(e, newenv)
      end
      retval
    when :set!
      var = env[l[1]]
      val = translate(l[2], env)
      puts "store i32 #{val}, i32* #{var}"
      val
    else
      args = l[1..-1].map{|e| translate(e, env)}
      retval = unique()
      puts "#{retval} = call i32 #{pred}(#{args.join(", ")})"
      retval
    end
  end
end

if $0 == __FILE__
  load "parser.rb"

  document = Parser.new.parse_with_debug($stdin.read)
  document = Transform.new.apply(document)
  document.each do |e|
    translate(e, {})
  end
end
