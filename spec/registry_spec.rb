require 'spec_helper'

describe Stubby::Registry do
  describe "#index" do
    subject { described_class.new }

    context "when remote index available" do
      before { stub_request(:get, /github\.com.*/).
                to_return(body: "{\"example2\": { \"v1.0.0\":\"http://example.com/stubby.zip\" }}", status:200) }

      it "provides a name => RegistryItem hash" do
        expect(subject.index).to have_key("example2")
        expect(subject.index["example2"]).to be_instance_of(Array)
        expect(subject.index["example2"].first).to be_instance_of(Stubby::RegistryItem)
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

  end

  describe "#latest" do

  end

  describe "#install" do

  end

  describe "#uninstall" do

  end
end
