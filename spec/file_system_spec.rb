require 'spec_helper'

describe Stubby::FileSystem do
  subject(:subject) { described_class.new }

  let(:paths) { Stubby::Paths }

  describe "#write_json" do
    it "writes 'contents' to 'target' as JSON" do
      json = Oj.dump({key: 'value'})
      expect(File).to receive(:write).with(paths.root_path, json)

      subject.write_json(paths.root_path, {key: 'value'})
    end
  end

  describe "#session_name" do
    it "returns the session name if set" do
      File.write paths.session_name_path, 'bob'

      expect(subject.session_name).eql?('bob')
    end

    it "returns 'default' if the session is not set" do
      expect(subject.session_name).eql?('default')
    end
  end

  describe "#remove_session" do
    it "deletes the json file for the given session" do
      File.write "#{paths.session_root_path}/bob.json", 'bob'

      subject.remove_session 'bob'

      expect(File.exists? "#{paths.session_root_path}/bob.json").eql?(false)
    end

    it "tells us if the named session doesn't exist" do
      expect(subject).to receive(:puts).with("[ERROR] Couldn't find session: bobs")

      subject.remove_session 'bobs'
    end
  end

  describe "#stubs" do
    before :each do
      paths.session_root_path
      FileUtils.mkdir_p ["#{paths.root_path}/lou", "#{paths.root_path}/bob", "#{paths.root_path}/bobbo"]

      File.write "#{paths.session_name_path}", "test"
      File.write "#{paths.session_root_path}/test.json", Oj.dump({"bob" => "staging", "bobbo" => "staging"})
      File.write "#{paths.root_path}/bob/stubby.json", Oj.dump(bogus_stubby)
      File.write "#{paths.root_path}/bobbo/stubby.json", Oj.dump(bogus_stubby)
      File.write "#{paths.root_path}/lou/stubby.json", Oj.dump(bogus_stubby)
    end

    it "returns all installed stubs" do
      expect(subject.stubs.keys).eql?(['bob', 'bobbo', 'lou'])
    end

    it "sets the target for stubs active in the session" do
      expect(subject.stubs.values.map(&:target)).eql?(['staging', 'staging', nil])
    end

    it "reports an error if an active stub isn't installed" do
      File.write "#{paths.session_root_path}/test.json", Oj.dump({"bob" => "staging", "timmy" => "staging"})

      expect(subject).to receive(:puts).with("[ERROR] timmy isn't installed!")

      expect { subject.stubs }.to raise_exception(SystemExit)
    end
  end

  def bogus_stubby
    {
      "staging" => { "reg" => "inst" },
      "production" => { "reg" => "inst" }
    }
  end
end