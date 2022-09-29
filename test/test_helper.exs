Mix.shell().cmd("mkdir -p test/gen")
Mix.shell().cmd("thrift --gen erlang:app_namespaces -out test/gen test/test.thrift")
:code.add_pathz('test/gen')
for file <- Path.wildcard("test/gen/*.erl") do
  Mix.shell().info("Compiling generated file \"#{file}\"...")
  :compile.file(
    Mix.Compilers.Erlang.to_erl_file(file),
    outdir: 'test/gen'
  )
end

ExUnit.start()
