require_relative './db_connection'

module Searchable
  def where(params)
  	where_list = params.keys.map{|key| "#{key} = ?"}

  	rows = DBConnection.execute(<<-SQL, *params.values)
  	SELECT * FROM #{table_name}
  	WHERE #{where_list.join("AND ")}
  	SQL

  	rows.map{|row| new row}
  end
end