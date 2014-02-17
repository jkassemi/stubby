require 'spec_helper'

describe Stubby::System do
  subject { 
    described_class.new.tap do |system|
      system.root_path = File.expand_path(".test") 
    end
  }

  before {
    if File.exists?(root_path)
      FileUtils.rm_r(root_path)
    end
  }

  let(:root_path){ File.expand_path(".test") }
  let(:session_root_path) { "#{root_path}/sessions" }
  let(:default_session_config_path) { "#{session_root_path}/default.json" } 
  let(:default_session_name_path) { "#{root_path}/sessions/current" }

  describe "#root_path" do
    it "'s ~/.stubby expanded" do
      expect(subject.root_path).to eq(root_path)
    end
  end

  describe "#session_root_path" do
    it "creates it when it doesn't exist" do
      allow(File).to receive(:exists?).with(anything()).and_call_original
      expect(File).to receive(:exists?).with(session_root_path).and_return(false)
      expect(FileUtils).to receive(:mkdir_p).and_return(true)
      subject.session_root_path
    end

    it "returns a reference to it" do
      expect(subject.session_root_path).to eq(session_root_path)
    end
  end

  describe "#session_config_path" do
    it "returns session config path" do
      expect(subject.session_config_path).to eq(default_session_config_path)
    end

    it "uses the session name" do
      subject.session_name = "example"
      expect(subject.session_config_path).to include("example")
    end      
  end

  describe "#session_name_path" do
    it "returns session name path" do
      expect(subject.session_name_path).to eq(default_session_name_path)
    end
  end

  describe "#session_name=" do
    it "Sets the session name" do
      subject.session_name= "example"
      expect(subject.session_name).to eq("example")    
    end

    it "Reloads session configuration" do
      expect(subject).to receive(:reload)
      subject.session_name= "example"
    end
  end

  describe "#current_session_name" do
    context "when none was written" do
      it "'s default" do
        expect(subject.current_session_name).to eq("default")
      end
    end

    context "when we've saved one before" do
      it "reads from the session file" do
        expect(subject.current_session_name).to eq("default")
        File.write(default_session_name_path, "example")
        expect(subject.current_session_name).to eq("example")
      end
    end
  end
end

