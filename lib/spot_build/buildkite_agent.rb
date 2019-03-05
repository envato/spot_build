require 'buildkit'
require 'socket'
require 'link_header'

module SpotBuild
  class BuildkiteAgent
    def initialize(token, org_slug)
      @client = Buildkit.new(token: token)
      @org_slug = org_slug
    end

    def the_end_is_nigh(host = Socket.gethostname)
      agents = agents_on_this_host(host)
      agents.each do |agent|
        stop_agent(agent, force: true)
      end
      agents.each do |agent|
        reschedule_job(agent.job)
      end
    end

    def stop_agent(agent, force: false)
      @client.stop_agent(@org_slug, agent.id, "{\"force\": #{force}}")
    rescue Buildkit::UnprocessableEntity
      # Swallow the error, this is generally thrown when the agent has already stopped
    end

    private

    RETRY_MESSAGE = /Only failed or timed out jobs can be retried/.freeze

    def reschedule_job(job)
      return if job.nil?
      retry_error(Buildkit::BadRequest, RETRY_MESSAGE) do
        @client.retry_job(@org_slug, job_pipeline(job[:build_url]), job_build(job[:build_url]), job[:id])
      end
    end

    def retry_error(error_class, message_regex, sleep: 2, retries: 20)
      begin
        yield
      rescue error_class => e
        if retries > 0 && e.message =~ message_regex
          sleep 0.5
          retries -= 1
          retry
        else
          raise
        end
      end
    end

    # build_url: https://api.buildkite.com/v2/organizations/my-great-org/pipelines/sleeper/builds/50
    def job_pipeline(build_url)
      build_url[%r{organizations/#{@org_slug}/pipelines/([^/]*)}, 1]
    end

    def job_build(build_url)
      build_url[%r{organizations/#{@org_slug}/pipelines/[^/]*/builds/([0-9]*)}, 1]
    end

    def agents_on_this_host(host)
      all_agents.select { |agent| agent.hostname == host }
    end

    def all_agents
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
