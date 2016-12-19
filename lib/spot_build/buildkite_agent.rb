require 'buildkit'
require 'socket'
require 'link_header'

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
      return unless agent_running?
      @client.stop_agent(@org_slug, agent_id, "{\"force\": #{force}}")
    end

    def agent_running?
      !agent.nil?
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
      @agent_id ||= agent.fetch(:id, nil)
    end

    def agent
      agents.select { |agent| agent.hostname == Socket.gethostname }.first
    end

    def agents
      with_pagination do |options = {}|
        @client.agents(@org_slug, options)
      end
    end

    # This is definately not thread safe
    def with_pagination(&block)
      results = yield
      while next_ref = next_link_ref(@client.last_response.headers["link"])
        uri = URI.parse(next_ref.href)
        next_page = uri.query.split("=")[1]
        results.push(yield page: next_page)
      end
      results.flatten
    end

    def next_link_ref(header)
      LinkHeader.parse(header).find_link(["rel", "next"])
    end
  end
end
