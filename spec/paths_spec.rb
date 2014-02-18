require 'spec_helper'

describe Stubby::Paths do
  subject(:subject) { described_class }

  let(:root_path){ File.expand_path(".test") }
  let(:session_root_path) { "#{root_path}/sessions" }
  let(:default_session_config_path) { "#{session_root_path}/default.json" } 
  let(:default_session_name_path) { "#{root_path}/sessions/current" }

  before do
    subject.root_path = File.expand_path '.test'
  end

  describe ".root_path" do
    it "returns @root_path if set" do
      expect(subject.root_path).eql?(root_path)
    end

    it "returns '~/.stubby' if @root_path not set" do
      subject.root_path = nil

      expect(subject.root_path).eql?("~/.stubby")
    end
  end

  describe ".session_root_path" do
    it "creates the sessions dir if it doesn't exist" do
      Stubby::Paths.session_root_path

      expect(File.exist? session_root_path).eql?(true)
    end

    # Bad Test
    it "doesn't modify the sessions dir if it already exists" do
      FileUtils.mkdir_p "#{subject.root_path}/sessions"
      File.write("#{subject.root_path}/sessions/tmp", ".")
      Stubby::Paths.session_root_path

      expect(File.exist? "#{session_root_path}/tmp").eql?(true)
    end
  end

  describe ".session_config_path" do
    it "returns the path for the given session name" do
      expect(subject.session_config_path("bob")).eql?("#{session_root_path}/bob.json")
    end
  end

  describe ".session_name_path" do
    it "returns .session_root_path + /current" do
      expect(subject.session_name_path).eql?(default_session_name_path)
    end
  end
end