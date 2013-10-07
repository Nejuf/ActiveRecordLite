require_relative './associatable'
require_relative './db_connection'
require_relative './mass_object'
require_relative './searchable'
require 'active_support/inflector'

class SQLObject < MassObject
  extend Searchable
  extend Associatable
  
  my_attr_accessible :table_name

  def self.set_table_name(table_name)
    @table_name = table_name.underscore.downcase.pluralize
  end

  def self.table_name
    set_table_name(self.name) if @table_name.nil?
    @table_name
  end

  def self.all
    rows = DBConnection.execute(<<-SQL)
    SELECT * FROM #{table_name}
    SQL

    rows.map do |row|
      new(row)
    end
  end

  def self.find(id)
    rows = where({:id => id})
    return nil if rows.empty?
    new rows.first
  end

  def save
    if nil?
      create
    else
      update
    end
  end

private
  def create
    arg_list = self.class.attributes.map(&:to_s).join(", ")
    arg_values = attribute_values
    q_marks = ("?"*arg_values.length).join(", ")
    
    DBConnection.execute(<<-SQL, arg_list, *arg_values)
    INSERT INTO #{self.class.table_name} ? VALUES #{q_marks}
    SQL

    self.class.find(DBConnection.last_insert_row_id)
  end

  def update
    name_list = self.class.attributes.dup
    name_list.shift
    set_list = name_list.map{|a| "#{a.to_s} = ?"}.join(", ")
    arg_values = attribute_values.dup
    arg_values.shift

    DBConnection.execute(<<-SQL, *arg_values, @id)
    UPDATE #{self.class.table_name} SET #{set_list} WHERE id = ?
    SQL
    self.class.find(@id)
  end

  def attribute_values
    self.class.attributes.map do |arg|
      send(arg)
    end
  end
end