require 'spec_helper'

describe SpotBuild::BuildkiteAgent do
  let(:org_slug) { "envato" }
  let(:pipeline) { "my-app" }
  subject { described_class.new('deadbeef', org_slug) }
  
  let(:last_response_stub) { instance_double(Sawyer::Response) }
  let(:buildkit_stub) { double("Buildkit", :agents => agent_stubs) }
  let(:hostname) { "i-1234567890" }
  let(:build_id) { "12345678" }

  def agent(id:, build_id: build_id, job_id: "1")
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

  describe '#the_end_is_nigh' do
    context 'the agent is not running' do
      let(:agent_stubs) { [] }

      it 'returns nil' do
        expect(subject.the_end_is_nigh).to equal(0)
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
        subject.the_end_is_nigh
      end

      it 'reschedules the job' do
        expect(buildkit_stub).to receive(:retry_job).with(org_slug, pipeline, build_id, '1')
        expect(buildkit_stub).to receive(:retry_job).with(org_slug, pipeline, build_id, '2')
        subject.the_end_is_nigh
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
        subject.the_end_is_nigh
      end
    end
  end
end
