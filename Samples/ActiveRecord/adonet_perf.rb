require 'rubyclr'

reference 'System.Data'

include System
include System::Data
include System::Data::SqlClient

CS = 'server=.\SQLEXPRESS;database=adventureworks;integrated security=sspi'

def get_data3
  records = RubyClr::get_data('select * from Person.Contact')
end

def get_data2
  auto_dispose(SqlConnection.new(CS)) do |conn|
    conn.open
    command = SqlCommand.new('select * from Person.Contact', conn)
    reader = command.execute_reader
    
    column_names = []
    0.upto(reader.field_count - 1) do |index|
      column_names << reader.get_name(index)
    end
  
    records = []  
    while reader.read
      attributes = {}
      0.upto(reader.field_count - 1) do |index|
        attributes[column_names[index]] = reader.get_value(index)
      end
      records << attributes
    end
  end
end

def get_data
  a = SqlDataAdapter.new('select * from Person.Contact', CS)
  ds = DataSet.new
  a.fill(ds)
  
  records = []
  table = ds.tables[0]
  rows = table.rows

  column_names = table.columns.collect { |column| column.column_name.to_sym }
  record_type = Struct.new(*column_names)
  
  0.upto(rows.count - 1) do |i|
    row = rows[i]
    fields = column_names.collect do |name|
      row[name.to_s]
    end
    records << record_type.new(*fields)
  end
end

def get_dataset
  a = SqlDataAdapter.new('select * from Person.Contact', CS)
  ds = DataSet.new
  a.fill(ds)
end

5.times { puts Benchmark.measure { get_data3 } }
5.times { puts Benchmark.measure { get_data2 } }
5.times { puts Benchmark.measure { get_dataset } }
readline