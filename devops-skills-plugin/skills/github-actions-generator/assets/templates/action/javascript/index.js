const core = require('@actions/core');
const github = require('@actions/github');

async function run() {
  try {
    // Get inputs
    const githubToken = core.getInput('github-token');
    const inputName = core.getInput('[input-name]', { required: true });

    // Log inputs (mask sensitive data)
    core.info(`Input: ${inputName}`);

    // Create GitHub client
    const octokit = github.getOctokit(githubToken);

    // Get context information
    const context = github.context;
    core.info(`Repository: ${context.repo.owner}/${context.repo.repo}`);
    core.info(`Event: ${context.eventName}`);

    // Main action logic
    core.startGroup('Running [ACTION_NAME]');

    // Example: Get repository information
    const { data: repo } = await octokit.rest.repos.get({
      owner: context.repo.owner,
      repo: context.repo.repo,
    });

    core.info(`Repository stars: ${repo.stargazers_count}`);

    // [ADD YOUR LOGIC HERE]

    core.endGroup();

    // Set outputs
    core.setOutput('[output-name]', '[OUTPUT_VALUE]');

    // Success
    core.info('✅ Action completed successfully');
  } catch (error) {
    // Handle errors
    core.setFailed(`Action failed: ${error.message}`);
    if (error.stack) {
      core.debug(error.stack);
    }
  }
}

run();
