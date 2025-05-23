require 'test_helper'

class NwoIngestorTest < ActiveSupport::TestCase
  setup do
    @user = users(:regular_user)
    @content_provider = content_providers(:another_portal_provider)
    mock_ingestions
    mock_timezone # System time zone should not affect test result
  end

  teardown do
    reset_timezone
  end

  test 'can ingest events from nwo' do
    source = @content_provider.sources.build(
      url: 'https://www.nwo.nl/en/meetings',
      method: 'nwo',
      enabled: true
    )

    ingestor = Ingestors::Taxila::NwoIngestor.new

    # check event doesn't
    new_title = 'NL Polar day 2025'
    new_url = 'https://www.nwo.nl/en/meetings/nl-polar-day-2025'
    refute Event.where(title: new_title, url: new_url).any?

    # run task
    assert_difference 'Event.count', 14 do
      freeze_time(2019) do
        VCR.use_cassette('ingestors/nwo') do
          ingestor.read(source.url)
          ingestor.write(@user, @content_provider)
        end
      end
    end

    assert_equal 14, ingestor.events.count
    assert ingestor.materials.empty?
    assert_equal 14, ingestor.stats[:events][:added]
    assert_equal 0, ingestor.stats[:events][:updated]
    assert_equal 0, ingestor.stats[:events][:rejected]

    # check event does exist
    event = Event.where(title: new_title, url: new_url).first
    assert event
    assert_equal new_title, event.title
    assert_equal new_url, event.url

    # check other fields
    assert_equal 'NL Polar day 2025', event.title
    assert_equal 'Amsterdam', event.timezone
    assert_equal 'NWO', event.source
    assert_equal Time.zone.parse('Mon, 8 Apr 2025 09:00:00.000000000 UTC +00:00'), event.start
    assert_equal Time.zone.parse('Mon, 8 Apr 2025 17:00:00.000000000 UTC +00:00'), event.end
  end
end
