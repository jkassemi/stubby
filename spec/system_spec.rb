require 'spec_helper'

describe Stubby::System do
  subject { 
    described_class.new.tap do |system|
      system.root_path = File.expand_path(".test") 
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

