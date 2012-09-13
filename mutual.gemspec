Gem::Specification.new do |s|
  s.name = "mutual"
  s.version = "0.1.0"
  s.authors = ["Daniel Yoder"]
  #s.homepage = ""
  s.summary = "A new project, a nascent bundle of win, whose author hasn't described it yet."

  s.files = %w[
    LICENSE
    README.md
  ] + Dir["lib/**/*.rb"]
  s.require_path = "lib"

  s.add_development_dependency("starter", ">=0.1.0")
end
