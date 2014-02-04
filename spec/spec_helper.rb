def read_fixture_file(file)
  File.read("#{File.dirname(__FILE__)}/validations/fixture/#{file}")
end
