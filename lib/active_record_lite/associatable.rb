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
    belongs_to_params = assoc_params(name)

    # e.g. post.author
    define_method(name) do
      other_table = belongs_to_params.other_table_name
      table = self.class.table_name
      primary_key = belongs_to_params.primary_key.to_s
      foreign_key = belongs_to_params.foreign_key.to_s
      self_id = self.send(belongs_to_params.foreign_key)

      rows = DBConnection.execute(<<-SQL, self.send(belongs_to_params.foreign_key))
      SELECT * FROM #{other_table}
      WHERE #{primary_key} = ?
      SQL

      belongs_to_params.other_class.new rows.first
    end

    #e.g. post.author=(author)
    define_method("#{name}=") do |arg|
      DBConnection.execute(<<-SQL, belongs_to_params.table_name, belongs_to_params.foreign_key.to_s, arg)
      UPDATE ? SET ? = ?
      SQL
    end

    #e.g. post.build_author

    #e.g. post.create_author

    #e.g. post.create_author!

    #parse all
    #belongs_to_params.other_class.parse_all().first
  end

  def has_many(name, params = {})
    @assoc_params ||= {}
    has_many_params = HasManyAssocParams.new(name, params, self)
    @assoc_params[name.to_sym] = has_many_params

    define_method(has_many_params.other_class_name.underscore.downcase.pluralize) do
      # rows = DBConnection.execute(<<-SQL, has_many_params.foreign_key.to_s, self.send(has_many_params.primary_key))
      # SELECT * FROM #{has_many_params.other_table_name}
      # WHERE ? = ?
      # SQL
      rows = DBConnection.execute(<<-SQL)
      SELECT * FROM #{has_many_params.other_table_name}
      WHERE #{has_many_params.foreign_key.to_s} = #{self.send(has_many_params.primary_key)}
      SQL

      return nil if rows.empty?
      rows.map { |row| has_many_params.other_class.new row }
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
    # @assoc_params ||= {}
    # @assoc_params[assoc1] = BelongsToAssocParams.new(name, assoc_params(assoc2))
    # p = assoc_params(name)

    #e.g. cat.house (cat belongs to human belongs to house)
    define_method(name) do
      p1 = self.class.assoc_params(assoc1)
      p2 = p1.other_class.assoc_params(assoc2)

      rows = DBConnection.execute(<<-SQL, self.send(p1.foreign_key))
      SELECT #{p2.other_table_name}.* FROM #{p1.other_table_name} JOIN #{p2.other_table_name}
      ON #{p1.other_table_name}.#{p2.foreign_key} = #{p2.other_table_name}.#{p2.primary_key}
      WHERE #{p1.other_table_name}.#{p1.primary_key} = ?
      SQL

      return nil if rows.empty?
      p2.other_class.new rows.first
    end

  end
end
