require 'spec_helper'

describe SpotBuild::BuildkiteAgent do
  let(:org_slug) { "envato" }
  subject { described_class.new('deadbeef', org_slug) }
  
  let(:last_response_stub) { instance_double(Sawyer::Response) }
  let(:buildkit_stub) { double("Buildkit", :agents => agent_stubs) }
  let(:hostname) { "i-1234567890" }

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
        expect(subject.the_end_is_nigh).to equal(nil)
      end
    end

    context 'the agent is running' do
      let(:agent_id) { 9876 }
      let(:agent_stubs) { 
        [double("BuildkiteAgent",
          hostname: hostname,
          id: agent_id,
          job: {build_url: "organizations/#{org_slug}/pipelines/my-app/builds/12345678", id: "12345678"}
        )]
      }

      before do
        allow(buildkit_stub).to receive(:stop_agent)
        allow(buildkit_stub).to receive(:retry_job)
      end

      it 'stops the agent forcefully' do
        expect(buildkit_stub).to receive(:stop_agent).with(org_slug, agent_id, '{"force": true}')
        subject.the_end_is_nigh
      end

      it 'reschedules the job' do
        expect(buildkit_stub).to receive(:retry_job)
        subject.the_end_is_nigh
      end
    end

    context 'the agent stops while we are trying to stop it' do
      let(:agent_id) { 9876 }
      let(:agent_stubs) { 
        [double("BuildkiteAgent",
          hostname: hostname,
          id: agent_id,
          job: {build_url: "organizations/#{org_slug}/pipelines/my-app/builds/12345678", id: "12345678"}
        )]
      }

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
