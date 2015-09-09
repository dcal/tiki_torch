describe 'request and response', integration: true do
  let(:consumer) { AdderConsumer }

  it 'requesting returns a future and in time we get a value' do
    hsh    = { numbers: [1, 2, 3], sleep_time: 5 }
    future = Tiki::Torch.request consumer.topic, hsh, timeout: 15

    expect(future).to be_a Concurrent::Future
    expect([:pending, :processing]).to include(future.state)
    expect(future.value(0)).to be_nil

    $lines.wait_for_size 1

    expect(future.value).to eq 6
    expect(future.state).to eq :fulfilled
  end

  it 'requesting returns a future that times out' do
    hsh    = { numbers: [1, 2, 3], sleep_time: 5 }
    future = Tiki::Torch.request consumer.topic, hsh, timeout: 2

    expect(future).to be_a Concurrent::Future
    expect([:pending, :processing]).to include(future.state)
    expect(future.value(0)).to be_nil

    sleep 2.5

    expect(future.value).to be_nil
    expect(future.state).to eq :rejected

    reason = future.reason
    expect(reason).to be_a Tiki::Torch::RequestTimedOutError
    expect(reason.timeout).to eq 2
    expect(reason.message_id).to be_a String
    expect(reason.topic_name).to eq consumer.topic
    expect(reason.payload).to eq hsh
    expect(reason.properties).to be_a Hash
  end

  it 'multiple requests concurrently' do
    futures    = 3.times.map do |nr|
      hsh = { numbers: [1, nr], sleep_time: 1 }
      Tiki::Torch.request consumer.topic, hsh, timeout: 15
    end
    start_time = Time.now
    values     = futures.map { |future| future.value }
    secs       = Time.now - start_time

    expect(values).to eq [1, 2, 3]
    expect(secs).to be < 2.0
  end

  context 'with a custom prefix', integration: false do
    let(:custom_prefix) { 'custom-' }

    before do
      $lines = TestingHelpers::LogLines.new
      Tiki::Torch.configure { |config| config.topic_prefix = custom_prefix }
      TestingHelpers.setup_torch
    end

    after do
      Tiki::Torch.configure { |config| config.topic_prefix = '' }
      TestingHelpers.take_down_torch
    end

    it 'should be able to successfully make a call' do
      hsh    = { numbers: [1, 2, 3], sleep_time: 5 }
      future = Tiki::Torch.request consumer.topic, hsh, timeout: 5

      expect(future).to be_a Concurrent::Future
      expect([:pending, :processing]).to include(future.state)
      expect(future.value(0)).to be_nil

      $lines.wait_for_size 1

      expect(future.value).to eq 6
      expect(future.state).to eq :fulfilled
    end
  end

end
