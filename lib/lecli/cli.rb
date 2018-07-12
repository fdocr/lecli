require "thor"

module LECLI
  class CLI < Thor

    desc "lecli pathname", "Returns a test lol"
    def pathname
      Pathname.new(__FILE__).parent.parent
    end

  end
end
