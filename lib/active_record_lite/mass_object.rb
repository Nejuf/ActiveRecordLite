class MassObject
  def self.my_attr_accessible(*attributes)
  	@attributes = attributes.map(&:to_sym)
  	attributes.each do |attr|
  		attr_accessor attr.to_sym
  	end
  end

  def self.attributes
  	@attributes
  end

  def self.parse_all(results)
    raise NotImplementedError
  end

  def initialize(params = {})
  	params.each do |attr_name, value|
  		if self.class.attributes.include?(attr_name.to_sym)
  			send("#{attr_name}=", value)
  		else
  			raise "mass assignment to unregistered attribute #{attr_name} on #{self}"
  		end
  	end
  end
end