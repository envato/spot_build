require 'buildkit'
require 'socket'

module SpotBuild
  class BuildkiteAgent
    def initialize(token, org_slug)
      @client = Buildkit.new(token: token)
      @org_slug = org_slug
    end

    def the_end_is_nigh
      job = current_job
      stop(true)
      reschedule_job(job)
    end

    def stop(force="false")
      @client.stop_agent(@org_slug, agent_id, "{\"force\": #{force}}")
    end

    private

    def reschedule_job(job)
      return if job.nil?
      @client.retry_job(@org_slug, job_pipeline(job[:build_url]), job_build(job[:build_url]), job[:id])
    end

    # build_url: https://api.buildkite.com/v2/organizations/my-great-org/pipelines/sleeper/builds/50
    def job_pipeline(build_url)
      build_url[%r{organizations/#{@org_slug}/pipelines/([^/]*)}, 1]
    end

    def job_build(build_url)
      build_url[%r{organizations/#{@org_slug}/pipelines/[^/]*/builds/([0-9]*)}, 1]
    end

    def current_job
      agent[:job]
    end

    def agent_id
      @agent_id ||= agent[:id]
    end

    def agent
      agents.select { |agent| agent.hostname == Socket.gethostname }.first
    end

    def agents
      @client.agents(@org_slug)
    end
  end
end
