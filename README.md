# Managing Spot Fleets with Buildkite

AWS EC2 Spot instances are cheaper, Buildkite Agents are a natural fit for Spot instnaces as the workload is interruptable.

SpotBuild makes it easier to use Spot instances and Spot fleets with Buildkite Agents by providing an agent that will shutdown the agent when the instance is scheduled for termination, preventing it from starting any new jobs and retry the current job it's working on.

# Running

Run this gem as a daemon on your buildkite agents and supply it the Organisation Slug and a Buildkite API token with the following permissions:
- read_agents
- read_builds
- write_builds
