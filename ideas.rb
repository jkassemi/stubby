=begin
agent port: 80 do |manager|
  manager.install do

  end

  manager.up do
    HTTPApp.run!(system)
  end

  manager.down do

  end
end

agent port: 443 do |manager|
  manager.install do
    # Generate keys
  end

  manager.up do
    @app = HTTPSApp.run!(system)
  end

  manager.down do
    # Nothing here
  end
end

agent port: 8801 do |manager|
  manager.stub do
    { "http://web.stubby.dev" => "http://localhost:8801" }
  end
end
=end
