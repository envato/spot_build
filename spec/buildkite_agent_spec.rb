require 'spec_helper'

describe SpotBuild::BuildkiteAgents do
  let(:org_slug) { "envato" }
  let(:pipeline) { "my-app" }
  subject(:buildkite_agent) { described_class.new('deadbeef', org_slug) }
  let(:last_response_stub) { instance_double(Sawyer::Response) }
  let(:buildkit_stub) { instance_double("Buildkit::Client", :agents => agent_stubs) }
  let(:hostname) { "i-1234567890" }
  let(:build_id) { "12345678" }

  def agent(id:, build_id: "12345678", job_id: "1")
    double("BuildkiteAgent#{id}",
      hostname: hostname,
      id: id,
      job: {build_url: "organizations/#{org_slug}/pipelines/#{pipeline}/builds/#{build_id}", id: job_id}
    )
  end

  before do
    allow(Buildkit).to receive(:new).and_return(buildkit_stub)
    allow(Socket).to receive(:gethostname).and_return(hostname)
    allow(buildkit_stub).to receive(:last_response).and_return(last_response_stub)
    allow(last_response_stub).to receive(:headers).and_return({"link" => nil})
  end

  describe '#agents_running' do
    context 'when agents are running' do
      let(:agent_stubs) { [agent(id: '123', build_id: build_id, job_id: '1')] }

      it 'returns true' do
        expect(buildkite_agent.agents_running?).to eq true
      end
    end

    context "when agents aren't running" do
      let(:agent_stubs) { [] }

      it 'returns false' do
        expect(buildkite_agent.agents_running?).to eq false
      end
    end
  end

  describe '#the_end_is_nigh' do
    context 'the agent is not running' do
      let(:agent_stubs) { [] }

      it 'does nothing' do
        expect(buildkit_stub).to_not receive(:stop_agent)
        expect(buildkit_stub).to_not receive(:retry_job)
        buildkite_agent.the_end_is_nigh
      end
    end

    context 'agents are running' do
      let(:agent_1_id) { '9876' }
      let(:agent_2_id) { '9877' }
      let(:agent_stubs) { [agent(id: agent_1_id, build_id: build_id, job_id: '1'),
                           agent(id: agent_2_id, build_id: build_id, job_id: '2')] }

      before do
        allow(buildkit_stub).to receive(:stop_agent)
        allow(buildkit_stub).to receive(:retry_job)
      end

      it 'stops each agent forcefully' do
        expect(buildkit_stub).to receive(:stop_agent).with(org_slug, agent_1_id, '{"force": true}')
        expect(buildkit_stub).to receive(:stop_agent).with(org_slug, agent_2_id, '{"force": true}')
        buildkite_agent.the_end_is_nigh
      end

      it 'reschedules the job' do
        expect(buildkit_stub).to receive(:retry_job).with(org_slug, pipeline, build_id, '1')
        expect(buildkit_stub).to receive(:retry_job).with(org_slug, pipeline, build_id, '2')
        buildkite_agent.the_end_is_nigh
      end

      context "when the jobs aren't retryable yet" do
        let(:agent_stubs) { [agent(id: agent_1_id, build_id: build_id, job_id: '1')] }

        it 'retries' do
          responses = [
            -> { raise Buildkit::BadRequest, {method: 'PUT', url: 'https://api.buildkite.com/v2/organizations/#{org_slug}/pipelines/#{pipeline}/builds/18961/jobs/1/retry', body: 'Only failed or timed out jobs can be retried'} },
            -> { nil }
          ]
          allow(buildkit_stub).to receive(:retry_job).with(org_slug, pipeline, build_id, '1') do
            response = responses.shift
            response.call if response
          end
          buildkite_agent.the_end_is_nigh
          expect(buildkit_stub).to have_received(:retry_job)
            .with(org_slug, pipeline, build_id, '1')
            .twice
        end
      end
    end

    context 'the agent stops while we are trying to stop it' do
      let(:agent_stubs) { [agent(id: '9876')] }

      before do
        allow(buildkit_stub).to receive(:stop_agent).and_raise(Buildkit::UnprocessableEntity)
        allow(buildkit_stub).to receive(:retry_job)
      end

      it 'retries the job' do
        expect(buildkit_stub).to receive(:retry_job)
        buildkite_agent.the_end_is_nigh
      end
    end
  end
end
