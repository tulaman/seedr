module Seedr
  class Video
    def self.attributes(*attributes)
      @@attr = attributes
      @@attr.each {|a| attr_accessor a}
    end

    attributes :id, :title, :description, :views, :votes, :rating, :comments, :page_url

    def initialize
      yield self if block_given?
    end

    def to_s
      lines = @@attr.collect do |a|
        name = a.to_s.split('_').map {|x| x.capitalize}.join(' ')
        "#{name}: #{self.send(a)}"
      end
      lines.join "\n"
    end
  end
end
