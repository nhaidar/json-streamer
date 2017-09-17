require 'spec_helper'

RSpec.describe Json::Streamer::JsonStreamer do

  before do
    @example_key = 'key'
    @example_value = 'value'
    @example_hash = {@example_key => @example_value}
    @chunk_size = 10
  end

  before do
    highlight('INPUT') do
      puts JSON.pretty_generate(hash) if defined?(hash)
    end if DEBUG
  end

  after do
    highlight('OUTPUT') do
      puts JSON.pretty_generate(yielded_objects) if defined?(yielded_objects)
    end if DEBUG
  end

  describe '#<<' do
    it 'forwards data to parser' do
      data = {}
      streamer = Json::Streamer.parser

      expect(streamer.parser).to receive(:<<).with(data)

      streamer << data
    end
  end

  describe '#get' do

    context '0th level of empty JSON object' do
      it 'should yield empty JSON object' do

        hash = {}
        json_file_mock = StringIO.new(JSON.generate(hash))
        streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

        objects = []
        streamer.get(nesting_level:0) do |object|
          objects << object
        end

        expect(objects.length).to eq(1)
        expect(objects[0]).to eq({})
      end
    end

    context '1st level from JSON' do
      it 'should yield objects within JSON object' do

        hash = {'object1':@example_hash, 'object2':@example_hash, 'object3':@example_hash}
        json_file_mock = StringIO.new(JSON.generate(hash))
        streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

        objects = []
        streamer.get(nesting_level:1) do |object|
          objects.push(object)
        end

        expect(objects.length).to eq(hash.length)
        objects.each do |element|
          expect(element).to eq(@example_hash)
        end
      end
    end

    context '1st level from JSON array' do
      it 'should yield objects in array elements' do

        array = Array.new(10) {@example_hash}
        json_file_mock = StringIO.new(JSON.generate(array))
        streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

        objects = []
        streamer.get(nesting_level:1) do |object|
          objects << object
        end

        expect(objects.length).to eq(array.length)
        objects.each do |element|
          expect(element).to eq(@example_hash)
        end
      end
    end

    context '1st level from EventMachine style input' do
      it 'should yield objects within JSON object' do

        hash = {'object1':@example_hash, 'object2':@example_hash, 'object3':@example_hash}
        streamer = Json::Streamer::JsonStreamer.new

        objects = []
        streamer.get(nesting_level:1) do |object|
          objects.push(object)
        end

        streamer.parser << JSON.generate(hash)

        expect(objects.length).to eq(hash.length)
        objects.each do |element|
          expect(element).to eq(@example_hash)
        end
      end
    end

    context '1st level from EventMachine style chunked input' do
      it 'should yield objects within JSON object' do

        hash = {'object1':@example_hash, 'object2':@example_hash, 'object3':@example_hash}
        streamer = Json::Streamer::JsonStreamer.new

        objects = []
        streamer.get(nesting_level:1) do |object|
          objects.push(object)
        end

        json_file_mock = StringIO.new(JSON.generate(hash))
        json_file_mock.each(@chunk_size) do |chunk|
          streamer.parser << chunk
        end

        expect(objects.length).to eq(hash.length)
        objects.each do |element|
          expect(element).to eq(@example_hash)
        end
      end
    end

    context 'JSONs with various nesting level and number of objects per level' do
      it 'should yield all objects on desired level (checking number of yielded objects)' do

        # Setting these options to high can cause the test to run longer
        entries_per_level = 2
        max_levels = 10

        (1..max_levels).each do |max_level|
          hash = NDHash.generate(levels: max_level, values_per_level: 0, hashes_per_level: entries_per_level)
          json_file_mock = StringIO.new(JSON.generate(hash))
          streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

          objects = []
          streamer.get(nesting_level:max_level-1) do |object|
            objects << object
          end

          expect(objects.length).to eq(entries_per_level**(max_level-1))
        end
      end
    end

    context 'Finished parsing' do
      it 'should remove object from memory' do

        hash = {obj:@example_hash}
        json_file_mock = StringIO.new(JSON.generate(hash))
        streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

        streamer.get(nesting_level:0) {}

        expect(streamer.aggregator.size).to eq(0)
      end
    end

    context 'Yield values enabled' do
      it 'should yield values from given level' do

        hash = {obj:@example_hash}
        json_file_mock = StringIO.new(JSON.generate(hash))
        streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

        objects = []
        streamer.get(nesting_level:2) do |object|
          objects << object
        end

        expect(objects.length).to eq(1)
        expect(objects[0]).to eq(@example_value)
      end
    end

    context 'Yield values disabled' do
      it 'should not yield values from given level' do

        hash = {obj:@example_hash}
        json_file_mock = StringIO.new(JSON.generate(hash))
        streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

        objects = []
        streamer.get(nesting_level:2, yield_values:false) do |object|
          objects << object
        end

        expect(objects.length).to eq(0)
      end
    end

    context 'By key from flat JSON' do
      it 'should yield value within JSON object' do

        json_file_mock = StringIO.new(JSON.generate(@example_hash))
        streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

        objects = []
        streamer.get(key:@example_key) do |object|
          objects.push(object)
        end

        expect(objects.length).to eq(@example_hash.length)
        objects.each do |element|
          expect(element).to eq(@example_value)
        end
      end
    end

    context 'By key from multi level JSON' do
      it 'should yield values within JSON object second level' do

        hash = {obj1:@example_hash, obj2:@example_hash, obj3:@example_hash}
        json_file_mock = StringIO.new(JSON.generate(hash))
        streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

        objects = []
        streamer.get(key:@example_key) do |object|
          objects.push(object)
        end

        expect(objects.length).to eq(hash.length)
        objects.each do |element|
          expect(element).to eq(@example_value)
        end
      end
    end

    context 'By key from multi level JSON' do
      it 'should yield values within JSON object from all levels the key occurs' do

        hash = {'obj1' => @example_hash, @example_key => @example_value}
        json_file_mock = StringIO.new(JSON.generate(hash))
        streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

        objects = []
        streamer.get(key:@example_key) do |object|
          objects.push(object)
        end

        expect(objects.length).to eq(2)
        objects.each do |element|
          expect(element).to eq(@example_value)
        end
      end
    end

    context 'By key from multi level JSON' do
      it 'should yield values and objects as well within JSON object from all levels the key occurs' do

        hash = {'obj1' => @example_hash, @example_key => @example_value, 'obj2' => {@example_key => @example_hash}}
        json_file_mock = StringIO.new(JSON.generate(hash))
        streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

        objects = []
        streamer.get(key:@example_key) do |object|
          objects.push(object)
        end

        expect(objects.length).to eq(4)
        objects[0..2].each do |element|
          expect(element).to eq(@example_value)
        end
        expect(objects[3]).to eq(@example_hash)
      end
    end

    context '2nd level of multi-level JSON array' do
      it 'should yield array elements' do

        hash = [[@example_hash, @example_hash, @example_hash]]
        json_file_mock = StringIO.new(JSON.generate(hash))
        streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

        objects = []
        streamer.get(nesting_level:2) do |object|
          objects.push(object)
        end

        expect(objects.length).to eq(3)
        objects.each do |element|
          expect(element).to eq(@example_hash)
        end
      end
    end

    context '1st level of multi-level JSON array' do
      it 'should yield array' do

        hash = [[@example_hash, @example_hash, @example_hash]]
        json_file_mock = StringIO.new(JSON.generate(hash))
        streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

        objects = []
        streamer.get(nesting_level:1) do |object|
          objects.push(object)
        end

        expect(objects.length).to eq(1)
        objects.each do |element|
          expect(element).to eq([@example_hash, @example_hash, @example_hash])
        end
      end
    end

    context '0th level of JSON array' do
      it 'should yield whole array' do

        hash = [@example_value, @example_value]
        json_file_mock = StringIO.new(JSON.generate(hash))
        streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

        objects = []
        streamer.get(nesting_level:0) do |object|
          objects.push(object)
        end

        expect(objects.length).to eq(1)
        expect(objects[0]).to eq([@example_value, @example_value])
      end
    end

    context '1th level of JSON array' do
      it 'should yield array elements' do

        hash = [@example_value, @example_value]
        json_file_mock = StringIO.new(JSON.generate(hash))
        streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

        objects = []
        streamer.get(nesting_level:1) do |object|
          objects.push(object)
        end

        expect(objects.length).to eq(2)
        objects.each do |element|
          expect(element).to eq(@example_value)
        end
      end
    end

    context 'issues' do
      let(:yielded_objects) { [] }

      context 'Issue #7' do
        context 'key pointing to nested array' do
          let(:hash) { {items:[[[@example_hash, @example_hash, @example_hash]]]} }

          it 'does not yield trailing empty arrays' do
            json_file_mock = StringIO.new(JSON.generate(hash))
            streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

            streamer.get(key: 'items') do |object|
              yielded_objects.push(object)
            end

            expect(yielded_objects.length).to eq(1)
          end

          it 'yields nested arrays with the correct nesting' do
            json_file_mock = StringIO.new(JSON.generate(hash))
            streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

            streamer.get(key: 'items') do |object|
              yielded_objects.push(object)
            end

            expect(yielded_objects.length).to eq(1)
            expect(yielded_objects[0]).to eq([[[@example_hash, @example_hash, @example_hash]]])
          end
        end

        context 'keys pointing to array' do
          let(:hash) { {items:{nested_items:[@example_hash, @example_value, @example_hash]}} }

          it 'yields array' do
            json_file_mock = StringIO.new(JSON.generate(hash))
            streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

            streamer.get(key: 'nested_items') do |object|
              yielded_objects.push(object)
            end

            expect(yielded_objects.length).to eq(1)
            expect(yielded_objects[0]).to eq([@example_hash, @example_value, @example_hash])
          end

          it 'keeps key pointing to arrays' do
            json_file_mock = StringIO.new(JSON.generate(hash))
            streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

            streamer.get(key: 'items') do |object|
              yielded_objects.push(object)
            end

            expect(yielded_objects.length).to eq(1)
            expect(yielded_objects[0]).to eq({'nested_items' => [@example_hash, @example_value, @example_hash]})
          end
        end
      end

      context 'Issue #8 values consumed' do
        let(:hash) { {items:{nested_items:[@example_value, @example_value, @example_value]}} }

        it 'does not consume values' do
          json_file_mock = StringIO.new(JSON.generate(hash))
          streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

          streamer.get(nesting_level:3, key: 'items') do |object|
            yielded_objects.push(object)
          end

          expect(yielded_objects.length).to eq(4)
          yielded_objects[0..2].each do |element|
            expect(element).to eq(@example_value)
          end
          expect(yielded_objects[3]).to eq({'nested_items' => [@example_value, @example_value, @example_value]})
        end
      end

      context 'nesting_level and key pointing to the same object' do
        let(:hash) { {items:{nested_items:[@example_value, @example_value, @example_value]}} }

        it 'yields the object once' do
          json_file_mock = StringIO.new(JSON.generate(hash))
          streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

          streamer.get(key: 'nested_items', nesting_level:2) do |object|
            yielded_objects.push(object)
          end

          expect(yielded_objects.length).to eq(1)
          expect(yielded_objects[0]).to eq([@example_value, @example_value, @example_value])
        end
      end
    end

    context '0th level of JSON object' do
      let(:hash) { hash = {'object' => @example_hash} }

      it 'yields whole JSON' do
        json_file_mock = StringIO.new(JSON.generate(hash))
        streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

        yielded_objects = []
        streamer.get(nesting_level:0) do |object|
          yielded_objects.push(object)
        end

        expect(yielded_objects).to eq([{'object' => @example_hash}])
      end
    end
  end

  context 'symbolize_keys' do
    let(:hash) { hash = {'object' => @example_hash} }

    it 'symbolizes keys' do
      json_file_mock = StringIO.new(JSON.generate(hash))
      streamer = Json::Streamer::JsonStreamer.new(json_file_mock, @chunk_size)

      yielded_objects = []
      streamer.get(nesting_level:0, symbolize_keys: true) do |object|
        yielded_objects.push(object)
      end

      expect(yielded_objects.length).to eq(hash.length)
      expect(yielded_objects[0]).to eq({object: {key: 'value'}})
    end
  end
end
