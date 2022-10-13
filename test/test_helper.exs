Mix.Task.run("compile.thrift", ["--verbose"])
Mix.Task.run("compile.woody", ["--verbose"])
ExUnit.start()
