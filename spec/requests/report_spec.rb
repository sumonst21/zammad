# Copyright (C) 2012-2023 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe 'Report', searchindex: true, type: :request do

  let!(:admin) do
    create(:admin)
  end
  let!(:year) do
    DateTime.now.utc.year
  end
  let!(:month) do
    DateTime.now.utc.month
  end
  let!(:week) do
    DateTime.now.utc.strftime('%U').to_i
  end
  let!(:day) do
    DateTime.now.utc.day
  end
  let!(:today) do
    Time.zone.parse('2019-03-15T08:00:00Z')
  end
  let!(:backends) do
    {
      'count::created':               true,
      'count::closed':                true,
      'count::backlog':               true,
      'create_channels::phone_in':    true,
      'create_channels::phone_out':   true,
      'create_channels::email_in':    true,
      'create_channels::email_out':   true,
      'create_channels::web_in':      true,
      'create_channels::twitter_in':  true,
      'create_channels::twitter_out': true,
      'communication::phone_in':      true,
      'communication::phone_out':     true,
      'communication::email_in':      true,
      'communication::email_out':     true,
      'communication::web_in':        true,
      'communication::twitter_in':    true,
      'communication::twitter_out':   true
    }
  end

  before do
    travel_to today.midday
    Ticket.destroy_all
    create(:ticket, title: 'ticket for report #1', created_at: today.midday)
    create(:ticket, title: 'ticket for report #2', created_at: today.midday + 2.hours)
    create(:ticket, title: 'ticket for report #3', created_at: today.midday + 2.hours)
    create(:ticket, title: 'ticket for report #4', created_at: today.midday + 10.hours, state: Ticket::State.lookup(name: 'closed'))
    create(:ticket, title: 'ticket for report #5', created_at: today.midday + 11.hours)
    create(:ticket, title: 'ticket for report #6', created_at: today.midday - 11.hours)
    create(:ticket, title: 'ticket for report #7', created_at: Time.zone.parse('2019-02-28T23:30:00Z'))
    create(:ticket, title: 'ticket for report #8', created_at: Time.zone.parse('2019-03-01T00:30:00Z'))
    create(:ticket, title: 'ticket for report #9', created_at: Time.zone.parse('2019-03-31T23:30:00Z'))
    create(:ticket, title: 'ticket for report #10', created_at: Time.zone.parse('2019-04-01T00:30:00Z'))

    searchindex_model_reload([Ticket, User])
  end

  describe 'request handling' do

    it 'does report example - admin access' do
      authenticated_as(admin)
      get "/api/v1/reports/sets?sheet=true;metric=count;year=#{year};month=#{month};week=#{week};day=#{day};timeRange=year;profile_id=1;downloadBackendSelected=count::created", params: {}, as: :json

      expect(response).to have_http_status(:ok)
      assert(response['Content-Disposition'])
      expect(response['Content-Disposition']).to eq('attachment; filename="tickets--all--Created.xlsx"; filename*=UTF-8\'\'tickets--all--Created.xlsx')
      expect(response['Content-Type']).to eq(ExcelSheet::CONTENT_TYPE)
    end

    it 'does report example - deliver result' do
      skip('No ES configured') if !SearchIndexBackend.enabled?

      authenticated_as(admin)

      # 2019-03-15 - day interval
      params = {
        metric:    'count',
        year:      today.year,
        month:     today.month,
        day:       today.day,
        timeRange: 'day',
        profiles:  {
          1 => true
        },
        backends:  backends
      }
      post '/api/v1/reports/generate', params: params, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['count::created']).to eq([0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0, 0, 0, 0, 1, 1])
      expect(json_response['data']['count::closed']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::backlog']).to eq([0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 1, 1])

      Setting.set('timezone_default', 'Europe/Berlin')
      post '/api/v1/reports/generate', params: params, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['count::created']).to eq([0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0, 0, 0, 0, 1])
      expect(json_response['data']['count::closed']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::backlog']).to eq([0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 1])

      Setting.set('timezone_default', 'America/Chicago')
      post '/api/v1/reports/generate', params: params, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['count::created']).to eq([0, 0, 0, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::closed']).to eq([0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::backlog']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0])

      Setting.set('timezone_default', 'Australia/Melbourne')
      post '/api/v1/reports/generate', params: params, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['count::created']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])
      expect(json_response['data']['count::closed']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])
      expect(json_response['data']['count::backlog']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

      # 2019-03 - month interval
      Setting.set('timezone_default', '')
      params = {
        metric:    'count',
        year:      today.year,
        month:     today.month,
        timeRange: 'month',
        profiles:  {
          1 => true
        },
        backends:  backends
      }

      post '/api/v1/reports/generate', params: params, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['count::created']).to eq([1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])
      expect(json_response['data']['count::closed']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::backlog']).to eq([1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])

      Setting.set('timezone_default', 'Europe/Berlin')
      post '/api/v1/reports/generate', params: params, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['count::created']).to eq([2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::closed']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::backlog']).to eq([2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

      Setting.set('timezone_default', 'America/Chicago')
      post '/api/v1/reports/generate', params: params, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['count::created']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2])
      expect(json_response['data']['count::closed']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::backlog']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2])

      Setting.set('timezone_default', 'Australia/Melbourne')
      post '/api/v1/reports/generate', params: params, as: :json
      expect(json_response['data']['count::created']).to eq([2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::closed']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::backlog']).to eq([2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

      # 2019-02 - month interval
      Setting.set('timezone_default', '')
      params = {
        metric:    'count',
        year:      today.year,
        month:     today.month - 1,
        timeRange: 'month',
        profiles:  {
          1 => true
        },
        backends:  backends
      }

      post '/api/v1/reports/generate', params: params, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['count::created']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])
      expect(json_response['data']['count::closed']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::backlog']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])

      Setting.set('timezone_default', 'Europe/Berlin')
      post '/api/v1/reports/generate', params: params, as: :json
      expect(json_response['data']['count::created']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::closed']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::backlog']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

      Setting.set('timezone_default', 'America/Chicago')
      post '/api/v1/reports/generate', params: params, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['count::created']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2])
      expect(json_response['data']['count::closed']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::backlog']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2])

      Setting.set('timezone_default', 'Australia/Melbourne')
      post '/api/v1/reports/generate', params: params, as: :json
      expect(json_response['data']['count::created']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::closed']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::backlog']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

      # 2019-04 - month interval
      Setting.set('timezone_default', '')
      params = {
        metric:    'count',
        year:      today.year,
        month:     today.month + 1,
        timeRange: 'month',
        profiles:  {
          1 => true
        },
        backends:  backends
      }

      post '/api/v1/reports/generate', params: params, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['count::created']).to eq([1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::closed']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::backlog']).to eq([1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

      Setting.set('timezone_default', 'Europe/Berlin')
      post '/api/v1/reports/generate', params: params, as: :json
      expect(json_response['data']['count::created']).to eq([2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::closed']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::backlog']).to eq([2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

      Setting.set('timezone_default', 'America/Chicago')
      post '/api/v1/reports/generate', params: params, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['count::created']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::closed']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::backlog']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

      Setting.set('timezone_default', 'Australia/Melbourne')
      post '/api/v1/reports/generate', params: params, as: :json
      expect(json_response['data']['count::created']).to eq([2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::closed']).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::backlog']).to eq([2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

      # 2019 - year interval
      Setting.set('timezone_default', '')
      params = {
        metric:    'count',
        year:      today.year,
        timeRange: 'year',
        profiles:  {
          1 => true
        },
        backends:  backends
      }
      post '/api/v1/reports/generate', params: params, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['count::created']).to eq([0, 1, 8, 1, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::closed']).to eq([0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::backlog']).to eq([0, 1, 7, 1, 0, 0, 0, 0, 0, 0, 0, 0])

      Setting.set('timezone_default', 'Europe/Berlin')
      post '/api/v1/reports/generate', params: params, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['count::created']).to eq([0, 0, 8, 2, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::closed']).to eq([0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::backlog']).to eq([0, 0, 7, 2, 0, 0, 0, 0, 0, 0, 0, 0])

      Setting.set('timezone_default', 'America/Chicago')
      post '/api/v1/reports/generate', params: params, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['count::created']).to eq([0, 2, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::closed']).to eq([0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::backlog']).to eq([0, 2, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0])

      Setting.set('timezone_default', 'Australia/Melbourne')
      post '/api/v1/reports/generate', params: params, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['count::created']).to eq([0, 0, 8, 2, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::closed']).to eq([0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      expect(json_response['data']['count::backlog']).to eq([0, 0, 7, 2, 0, 0, 0, 0, 0, 0, 0, 0])
    end
  end
end
