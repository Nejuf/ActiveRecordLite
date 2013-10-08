require 'active_support/core_ext/object/try'
require 'active_support/inflector'
require_relative './db_connection.rb'

class AssocParams
  def other_class
    @other_class_name.constantize
  end

  def other_table
    raise NotImplementedError
  end

  def other_table_name
    other_class.table_name
  end
end

class BelongsToAssocParams < AssocParams
  attr_accessor :other_class_name, :primary_key, :foreign_key
  def initialize(name, params)
    @other_class_name = params[:class_name]
    @other_class_name ||= name.to_s.camelcase
    
    #@other_table_name = @other_class.table_name

    @primary_key = params[:primary_key]
    @primary_key ||= :id

    @foreign_key = params[:foreign_key]
    @foreign_key ||= "#{name}_id".to_sym
  end

  def type
    :belongs_to
  end
end

class HasManyAssocParams < AssocParams
  attr_accessor :other_class_name, :primary_key, :foreign_key

  def initialize(name, params, self_class)
    @other_class_name = params[:class_name]
    @other_class_name ||= name.to_s.singularize.camelcase

   # @other_table_name = @other_class.table_name

    @primary_key = params[:primary_key]
    @primary_key ||= :id

    @foreign_key = params[:foreign_key]
    @foreign_key ||= "#{self_class.to_s.snake_case}_id".to_sym
  end

  def type
    :has_many
  end
end

module Associatable
  def assoc_params(name)
    @assoc_params ||= {}
    @assoc_params[name.to_sym]
  end

  def belongs_to(name, params = {})
    @assoc_params ||= {}
    @assoc_params[name.to_sym] = BelongsToAssocParams.new(name, params)
    p = assoc_params(name)

    # e.g. post.author
    define_method(name) do
      other_table = p.other_table_name
      table = self.class.table_name
      primary_key = p.primary_key.to_s
      foreign_key = p.foreign_key.to_s
      self_id = self.send(p.foreign_key)
      p other_table
      p table
      p primary_key
      p foreign_key
      p self_id
      puts "test--"
      p self.class.assoc_params(name).primary_key.to_s
      rows = DBConnection.execute(<<-SQL, self.send(p.foreign_key))
      SELECT * FROM #{other_table} 
      WHERE #{primary_key} = ?
      SQL

      p rows
      p.other_class.new rows.first
    end

    #e.g. post.author=(author)
    define_method("#{name}=") do |arg|
      DBConnection.execute(<<-SQL, p.table_name, p.foreign_key.to_s, arg)
      UPDATE ? SET ? = ?
      SQL
    end

    #e.g. post.build_author

    #e.g. post.create_author

    #e.g. post.create_author!

    #parse all
    #p.other_class.parse_all().first
  end

  def has_many(name, params = {})
    @assoc_params ||= {}
    p = HasManyAssocParams.new(name, params, self)
    @assoc_params[name.to_sym] = p
#     puts "has_many"
# p p.foreign_key.to_s
# p p.primary_key
# p self
# p self.class
    #e.g. user.posts
    define_method(p.other_class_name.underscore.downcase.pluralize) do 
      p "user.posts"
      p self.send(p.primary_key)
      p p.foreign_key.to_s
      # rows = DBConnection.execute(<<-SQL, p.foreign_key.to_s, self.send(p.primary_key))
      # SELECT * FROM #{p.other_table_name}
      # WHERE ? = ?
      # SQL
      rows = DBConnection.execute(<<-SQL)
      SELECT * FROM #{p.other_table_name}
      WHERE #{p.foreign_key.to_s} = #{self.send(p.primary_key)}
      SQL
    
      p rows
      return nil if rows.empty?
      rows.map { |row| p.other_class.new row }
    end

    #e.g. user.posts<<
    #e.g. user.posts.delete
    #e.g. user.pots=
    #e.g. user.post_ids
    #e.g. user.pots.clear
    #e.g. user.posts.empty?
    #e.g. user.posts.size
    #e.g. user.pots.find
    #e.g. user.posts.exists?
    #e.g. user.posts.build
    #e.g. user.pots.create

  end

  def has_one_through(name, assoc1, assoc2)
puts "has_one_through #{name} #{assoc1} #{assoc2}"
    # @assoc_params ||= {}
    # @assoc_params[assoc1] = BelongsToAssocParams.new(name, assoc_params(assoc2))
    # p = assoc_params(name)

    #e.g. cat.house (cat belongs to human belongs to house)
    define_method(name) do 
      p1 = self.class.assoc_params(assoc1)
      p2 = p1.other_class.assoc_params(assoc2)
# p "has_one_through"
# p p1
# p p2
# p p1.other_table_name
# p p2.other_table_name
# p "SELECT #{p2.other_table_name}.* FROM #{p1.other_table_name} JOIN #{p2.other_table_name}"
# p "ON #{p1.other_table_name}.#{p2.foreign_key} = #{p2.other_table_name}.#{p2.primary_key}"
# p "WHERE #{p1.other_table_name}.#{p1.primary_key} = #{self.send(p1.foreign_key)}"
      rows = DBConnection.execute(<<-SQL, self.send(p1.foreign_key))
      SELECT #{p2.other_table_name}.* FROM #{p1.other_table_name} JOIN #{p2.other_table_name}
      ON #{p1.other_table_name}.#{p2.foreign_key} = #{p2.other_table_name}.#{p2.primary_key}
      WHERE #{p1.other_table_name}.#{p1.primary_key} = ?
      SQL
      
      p rows
      return nil if rows.empty?
      p2.other_class.new rows.first
    end

  end
end
