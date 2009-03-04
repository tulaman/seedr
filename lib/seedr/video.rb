module Seedr
  class Video
    attr_accessor :id, :title, :desc

    def initialize(id, title, desc)
      @id = id
      @title = title
      @desc = desc
    end

    def to_s
      "\#<#{self.class} \##{@id} #{@title}>"
    end
  end
end
