$counter = 0

def unique(name='%_')
  $counter += 1
  "#{name}#{$counter}"
end

$temp_counter = 0
def temporary
  $temp_counter += 1
  "%_#$temp_counter"
end

$builtins = {}
{:+ => "add",
 :- => "sub",
 :* => "mul",
 :/ => "sdiv"}.each do |sym, inst|
  $builtins[sym] = ->(a, b) {
    retval = temporary()
    puts "#{retval} = #{inst} i32 #{a}, #{b}"
    retval
  }
end

{'='.to_sym => "eq",
 :not= => "neq",
 :> => "sgt",
 :< => "slt"}.each do |sym, cond|
  $builtins[sym] = ->(a, b) {
    retval = temporary()
    puts "#{retval} = icmp #{cond} i32 #{a}, #{b}"
    retval
  }
end

def new_scope(varnames, env)
  newenv = env.dup
  varnames.each do |sym|
    name, _ = *sym
    p = "%#{name}"
    symname = unique(p)
    val = yield sym
    puts "#{symname} = alloca i32"
    puts "store i32 #{val}, i32* #{symname}"
    newenv[name] = symname
  end
  newenv
end

def translate(expr, env)
  case expr
  when Numeric
    "#{expr}"
  when Symbol
    retval = temporary()
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
      arglist = params.map{|a| "i32 %#{a}"}

      puts "define i32 @#{name}(#{arglist.join(", ")}) {"

      newenv = new_scope(params, {}) {|param| "%#{param}"}

      retval = "void"
      body.each do |e|
        retval = translate(e, newenv)
      end

      puts "ret i32 #{retval}"
      puts "}"
    when :let
      varlist = l[1]

      newenv = new_scope(varlist, env) do |sym, expr|
        translate(expr, env)
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
    when :if
      cond = translate(l[1], env)
      true_br = l[2]
      true_label = unique('true')
      false_br = l[3]
      false_label = unique('false')
      join_label = unique('join')
      puts "br i1 #{cond}, label %#{true_label}, label %#{false_label}"
      puts "#{true_label}:"
      true_val = translate(true_br, env)
      puts "br label %#{join_label}"
      puts "#{false_label}:"
      if false_br
        false_val = translate(false_br, env)
      else
        false_val = "0"
      end
      puts "br label %#{join_label}"
      puts "#{join_label}:"
      retval = temporary()
      puts "#{retval} = phi i32 [#{true_val}, %#{true_label}], [#{false_val}, %#{false_label}]"
      retval
    when :while
      cond = l[1]
      body = l[2..-1]

      in_label = unique('in')
      top_label = unique('top')
      test_label = unique('test')
      out_label = unique('out')
      puts "br label %#{in_label}"
      puts "#{in_label}:"
      puts "br label %#{test_label}"
      puts "#{top_label}:"
      bodyval = "i32 0"
      body.each do |e|
        bodyval = translate(e, env)
      end
      puts "br label %#{test_label}"
      puts "#{test_label}:"
      retval = temporary()
      puts "#{retval} = phi i32 [0, %#{in_label}], [#{bodyval}, %#{top_label}]"
      cond = translate(cond, env)
      puts "br i1 #{cond}, label %#{top_label}, label %#{out_label}"
      puts "#{out_label}:"
      retval
    else
      args = l[1..-1].map{|e| translate(e, env)}
      if $builtins.include? pred
        $builtins[pred].(*args)
      else
        retval = temporary()
        argnames = args.map{|a| "i32 #{a}"}
        puts "#{retval} = call i32 @#{pred}(#{argnames.join(", ")})"
        retval
      end
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
