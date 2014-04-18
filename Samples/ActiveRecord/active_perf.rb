# A simple set of experiments that seeks to compare the relative perf
# of ActiveRecord reading stuff vs. a hyptothetical RubyCLR + ADO.NET
# implementation.

require_gem 'activerecord'
require 'benchmark'

include ActiveRecord

Base.establish_connection(:adapter  => 'sqlserver',
                          :host     => '.\SQLEXPRESS',
                          :database => 'adventureworks')

class Contact < Base
  set_table_name 'Person.Contact'
  set_primary_key 'ContactID'
end

puts Benchmark.measure { records = Contact.find_all }

readline