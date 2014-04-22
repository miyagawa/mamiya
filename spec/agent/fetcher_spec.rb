require 'spec_helper'

require 'mamiya/agent/fetcher'
require 'mamiya/steps/fetch'

describe Mamiya::Agent::Fetcher do
  subject(:fetcher) { described_class.new(destination: 'destination') }

  describe "lifecycle" do
    it "can start and stop" do
      expect(fetcher.thread).to be_nil
      expect(fetcher).not_to be_running

      fetcher.start!

      expect(fetcher).to be_running
      expect(fetcher.thread).to be_a(Thread)
      expect(fetcher.thread).to be_alive
      th = fetcher.thread

      fetcher.stop!

      10.times { break unless th.alive?; sleep 0.1 }
      expect(th).not_to be_alive

      expect(fetcher.thread).to be_nil
      expect(fetcher).not_to be_running
    end

    it "can graceful stop"
  end

  describe "mainloop" do
    before do
      allow(step).to receive(:run!)
      allow(Mamiya::Steps::Fetch).to receive(:new).with(
        application: 'myapp',
        package: 'package',
        destination: 'destination',
      ).and_return(step)

      fetcher.start!
    end

    let(:step) { double('fetch-step') }

    it "starts fetch step for each order" do
      flag = false

      expect(step).to receive(:run!) do
        flag = true
      end

      fetcher.enqueue('myapp', 'package')
      fetcher.stop!(:graceful)
    end

    it "calls callback" do
      received = true

      fetcher.enqueue('myapp', 'package') do |succeeded|
        received = succeeded
      end

      fetcher.stop!(:graceful)

      expect(received).to be_nil
    end

    context "when fetch step raised error" do
      let(:exception) { Exception.new("he he...") }

      before do
        allow(step).to receive(:run!).and_raise(exception)
      end

      it "calls callback with error" do
        received = nil

        fetcher.enqueue('myapp', 'package') do |error|
          received = error
        end

        fetcher.stop!(:graceful)

        expect(received).to eq exception
      end
    end

    after do
      fetcher.stop!
    end
  end
end