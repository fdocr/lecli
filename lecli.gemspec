
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "lecli/version"

Gem::Specification.new do |spec|
  spec.name          = "lecli"
  spec.version       = LECLI::VERSION
  spec.authors       = ["Fernando Valverde Arredondo"]
  spec.email         = ["fdov88@gmail.com"]

  spec.summary       = "Let's Encrypt CLI to generate certificates"
  spec.description   = "Let's Encrypt CLI to generate certificates"
  spec.homepage      = "https://github.com/fdoxyz/lecli"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 0.20.0"

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"

end
