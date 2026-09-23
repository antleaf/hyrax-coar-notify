# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::CoarNotify::Scheduler do
  after { Hyrax::CoarNotify.reset_configuration! }

  describe '.schedule_entry' do
    it 'points at the fetch job using the configured cron string' do
      Hyrax::CoarNotify.config.fetch_schedule = '*/10 * * * *'

      expect(described_class.schedule_entry).to eq(
        'cron' => '*/10 * * * *',
        'class' => 'Hyrax::CoarNotify::FetchNotificationsJob'
      )
    end
  end

  describe '.register!' do
    context 'when sidekiq-scheduler is loaded (as in this app)' do
      it 'registers only its own named schedule entry, once actually running as a Sidekiq server' do
        allow(Sidekiq).to receive(:server?).and_return(true)
        expect(Sidekiq).to receive(:set_schedule).with(described_class::SCHEDULE_NAME, described_class.schedule_entry)

        described_class.register!
      end

      it 'does not touch the schedule outside of a real Sidekiq server process (e.g. web, console)' do
        allow(Sidekiq).to receive(:server?).and_return(false)
        expect(Sidekiq).not_to receive(:set_schedule)

        described_class.register!
      end
    end

    context 'when sidekiq-scheduler is not available' do
      before { allow(described_class).to receive(:schedulable?).and_return(false) }

      it 'is a no-op' do
        expect(Sidekiq).not_to receive(:set_schedule)

        described_class.register!
      end
    end
  end
end
