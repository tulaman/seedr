class Object
  def full_const_get(name)
    list = name.split("::")
    obj = Object
    list.each {|x| obj = obj.const_get(x) }
    obj
  end
end

class String
  def camelize
    self.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_|\.)(.)/) { $1.upcase }
  end

  def to_const
    Object.full_const_get(self.camelize)
  end
end
