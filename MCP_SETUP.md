# MCP Server Configuration

This project uses Model Context Protocol (MCP) servers to integrate with external services.

## Configured MCP Servers

### Sentry
- **Type**: HTTP
- **Configuration**: Automatic (no credentials needed)
- **Purpose**: Error tracking and monitoring

### Jira
- **Type**: STDIO
- **Configuration**: Requires environment variables
- **Purpose**: Issue tracking and project management

## Setting Up Jira MCP

### 1. Get Your Jira Credentials

You need:
- **JIRA_URL**: Your Atlassian workspace URL (e.g., `https://your-workspace.atlassian.net`)
- **JIRA_EMAIL**: Your Atlassian account email
- **JIRA_API_TOKEN**: Personal API token from Atlassian

### 2. Create Jira API Token

1. Go to https://id.atlassian.com/manage-profile/security/api-tokens
2. Click "Create API token"
3. Give it a name (e.g., "Claude Code MCP")
4. Copy the generated token

### 3. Add to Your Local Environment

Add these variables to your `.env.local` file:

```bash
# Jira MCP Configuration
JIRA_URL=https://your-workspace.atlassian.net
JIRA_EMAIL=your.email@example.com
JIRA_API_TOKEN=your-api-token-here
```

**Important**:
- `.env.local` is gitignored and won't be committed
- Each developer needs their own API token
- Never commit API tokens to the repository

### 4. Restart Claude Code

After adding the environment variables, restart Claude Code CLI to pick up the new configuration.

## Testing Jira MCP

Once configured, you can use Jira MCP tools in Claude Code:
- Search for issues
- Create new issues
- Update issue status
- Add comments
- Get issue details

## Troubleshooting

**MCP server not connecting:**
- Verify your `.env.local` has all three required variables
- Check that your API token is valid
- Ensure your JIRA_URL doesn't have a trailing slash

**Permission errors:**
- Verify your Jira account has appropriate permissions
- Check that the API token hasn't expired

## Additional MCP Servers

To add more MCP servers, edit `.mcp.json` and add environment variables to `.env.local` as needed.

For MCP documentation, see: https://modelcontextprotocol.io/
