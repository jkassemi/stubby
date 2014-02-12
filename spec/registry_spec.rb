require 'spec_helper'

describe Stubby::Registry do
  subject { 
    described_class.new 
  }

  before { 
    stub_request(:get, /github\.com.*/).
      to_return(body: Oj.dump({
        "example" => {
          "v1.0.0" => "http://example.com/stubby.zip",
          "v2.0.0" => "http://example.com/stubby2.zip"
        }
      }), status: 200)
  }

  describe "#index" do
    context "when remote index available" do
      it "provides a name => RegistryItem hash" do
        expect(subject.index).to have_key("example")
        expect(subject.index["example"]).to be_instance_of(Array)
        expect(subject.index["example"].first).to be_instance_of(Stubby::RegistryItem)
      end
    end

    context "when remote index not available" do
      before { stub_request(:get, /github\.com.*/).
                to_return(status: 500) }

      it "provides a name => RegistryItem hash" do
        expect(subject.index).to have_key("example")
        expect(subject.index["example"]).to be_instance_of(Array)
        expect(subject.index["example"].first).to be_instance_of(Stubby::RegistryItem)
      end
    end
  end

  describe "#versions" do
    context "when stub found" do
      it "gives a sorted list of version" do
        expect(subject.versions("example")).to be_instance_of(Array)
        expect(subject.versions("example").length).to eq(2)
        expect(subject.versions("example").first.version).to eq("2.0.0")
      end      
    end

    context "when stub not found" do
      it "gives an empty array" do
        expect(subject.versions("nope")).to eq([])
      end
    end
  end

  describe "#latest" do

  end

  describe "#install" do

  end

  describe "#uninstall" do

  end
end
